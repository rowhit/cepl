(in-package :cgl)
;;------------------------------------------------------------

(defun slot-name (slot) (first slot))
(defun slot-type (slot) (second slot))
(defun slot-normalisedp (slot) (third slot))

(defun make-cstruct-def (name slots)
  `(defcstruct ,name
     ,@(loop for slot in slots :collect 
            (let ((ptype (varjo:type-principle (slot-type slot))))
              (list (slot-name slot)
                    (if (varjo:type-aggregate-p ptype)
                        (varjo:type-principle (slot-type slot))
                        ptype)
                    :count (if (varjo:type-arrayp (slot-type slot))
                               (varjo:type-array-length (slot-type slot))
                               1))))))

(defun make-translators (name type-name value-name slots struct-name)
  (let ((slot-names (mapcar #'first slots)))
    `((defmethod translate-from-foreign (ptr (type ,type-name))
        (make-instance ',value-name :element-type ',name :pointer ptr))
      (defmethod translate-into-foreign-memory
          ((value t) (type ,type-name) pointer)
        (print "NO EFFECT: This style of setting c structs not yet implemented")
        nil)
      (defmethod translate-into-foreign-memory
          ((value list) (type ,type-name) pointer)
        (destructuring-bind ,slot-names value
          ,@(loop :for slot-definition :in slots :collecting
               (destructuring-bind (slot-name vslot-type normalised accessor)
                   slot-definition
                 (declare (ignore normalised accessor))
                 (if (varjo:type-arrayp vslot-type)
                     ;;if array
                     `(let ((array-ptr (foreign-slot-pointer 
                                        pointer '(:struct ,struct-name)
                                        ',slot-name)))
                        (loop for datum in ,slot-name for i from 0 do
                             (setf (mem-aref array-ptr 
                                            ',(varjo:type-principle vslot-type)
                                            i)
                                   datum)))
                     ;;if value
                     `(setf (mem-ref (foreign-slot-pointer
                                      pointer '(:struct ,struct-name)
                                      ',slot-name) 
                                     ',(varjo:type-principle vslot-type))
                            ,slot-name)))))))))

;; [TODO] Use 'normalize' 
;; [TODO] the setter seems ugly, gotta be a better way
;; [TODO] got to handle aggregate and complex types
;; [TODO] can glsl and thus varjo have multidimensional arrays?
;; [TODO] If slot struct type return a c-value
;;        (make-instance ',value-name :element-type ',name :pointer ptr)
(defun make-getters-and-setters (name value-name struct-name slots)
  (loop for slot-definition in slots appending
       (destructuring-bind (slot-name vslot-type normalised accessor)
           slot-definition
         (declare (ignore normalised))
         `((defmethod ,(or accessor (utils:symb name '- slot-name)) 
               ((gl-object ,value-name))
             ,(if (varjo:type-arrayp vslot-type)
                  `(make-c-array-from-pointer 
                    ',(let ((len (varjo:type-array-length vslot-type)))
                           (if (listp len) len (list len)))
                    ,(varjo:type-principle vslot-type)
                    (foreign-slot-pointer (pointer gl-object)
                                          '(:struct ,struct-name)
                                          ',slot-name))
                  `(foreign-slot-value (pointer gl-object) 
                                       '(:struct ,struct-name)
                                       ',slot-name)))
           ,(if (varjo:type-arrayp vslot-type)
                `(defmethod (setf ,(or accessor (utils:symb name '- slot-name)))
                     ((value list) (gl-object ,value-name))
                   (let ((array-ptr (foreign-slot-pointer
                                     (pointer gl-object) '(:struct ,struct-name)
                                     ',slot-name)))
                     (loop for datum in value for i from 0 do
                          (setf (mem-aref array-ptr 
                                          ',(varjo:type-principle vslot-type) i)
                                datum))
                     value))
                `(defmethod (setf ,(or accessor (utils:symb name '- slot-name)))
                     ((value t) (gl-object ,value-name))             
                   (setf (mem-ref (foreign-slot-pointer (pointer gl-object) 
                                                        '(:struct ,struct-name)
                                                        ',slot-name) 
                                  ',(varjo:type-principle vslot-type))
                         value)))))))


(defmacro defglstruct (name &body slot-descriptions)
  (when (keywordp name) (error "Keyword name are now allowed for glstructs"))
  (let ((slots (loop for slot in slot-descriptions collect
                    (destructuring-bind 
                          (slot-name slot-type &key (normalised nil) 
                                     (accessor nil) &allow-other-keys)
                        slot
                      (list slot-name (varjo:flesh-out-type slot-type) 
                            normalised accessor))))
        (struct-name (utils:symb name '-struct))
        (type-name (utils:symb name '-type))
        (value-name (utils:symb name '-value)))
    `(progn
       (varjo:vdefstruct ,name
         ,@(loop for slot in slots
              collect (append (subseq slot 0 2) 
                              (list nil nil)
                              (last slot))))
       ,(make-cstruct-def struct-name slots)
       (define-foreign-type ,type-name () 
         ()
         (:actual-type :struct ,struct-name)
         (:simple-parser ,name))
       (defclass ,value-name (c-value) ())
       ,@(make-translators name type-name value-name slots struct-name)
       ,@(make-getters-and-setters name value-name struct-name slots)
       ,(make-gl-struct-attrib-assigner name slots)
       ',name)))

                                        ;(defglstruct mystruct (a :vec3) (b :vec4))

(defun expand-slot-to-layout (slot)
  (destructuring-bind (type normalise &rest ign)
      slot
    (declare (ignore ign))
    (let ((type (varjo:flesh-out-type type)))
      (cond 
        ((varjo:type-arrayp type) 
         (loop for i below (varjo:type-array-length type)
            :append (expand-slot-to-layout 
                     (list (varjo:flesh-out-type 
                            (varjo:type-principle type))
                           normalise))))
        ((varjo:mat-typep type) 
         (loop for i below (varjo:mat/vec-length type)
            :append (expand-slot-to-layout 
                     (list (varjo:type-mat-col-to-vec type)
                           normalise))))
        ((varjo:vec-typep type) 
         `((,(varjo:mat/vec-length type) 
             ,(varjo:type-vec-core-type type) 
             ,normalise)))
        (t `((1 ,(varjo:type-principle type) ,normalise)))))))

(defun make-gl-struct-attrib-assigner (type-name slots)
  (when (every #'varjo:type-built-inp (mapcar #'slot-type slots))
    (let* ((stride (if (> (length slots) 1)
                       `(cffi:foreign-type-size ',type-name)
                       0))
           (stride-sym (gensym "stride"))
           (definitions 
            (loop :for attr :in 
               (mapcan #'(lambda (x) (expand-slot-to-layout (subseq x 1))) 
                       slots)
               :for i :from 0
               :with offset = 0
               :append `((gl:enable-vertex-attrib-array (+ attrib-offset ,i))
                         (%gl:vertex-attrib-pointer 
                          (+ attrib-offset ,i) ,@attr ,stride-sym 
                          (cffi:make-pointer (+ ,offset pointer-offset))))
               :do (setf offset (+ offset 
                                   (* (first attr) 
                                      (cffi:foreign-type-size 
                                       (second attr))))))))
      (when definitions
        `(defmethod gl-assign-attrib-pointers ((array-type (EQL ',type-name)) 
                                               &optional (attrib-offset 0)
                                                 (pointer-offset 0)
                                                 stride-override normalised)
           (declare (ignore array-type normalised))
           (let ((,stride-sym (or stride-override ,stride)))
             ,@definitions
             ,(length definitions)))))))