(in-package :primitives)

;; [TODO] Add Cone & Cylinder

(defun prim-array (type &optional (size 1.0) (gpu-array t) (stream nil))
  (destructuring-bind (pn f) (primitive-data type :size size)
    (let ((verts
           (if gpu-array
               (cgl:make-gpu-array pn :element-type 'cgl:p-n-t
                                   :dimensions (length pn))
               (cgl:make-c-array (length pn) 'cgl:p-n-t :initial-contents pn)))
          (index
           (when f
             (if gpu-array
                 (cgl:make-gpu-array f :element-type :unsigned-short
                                     :dimensions (length f))
                 (cgl:make-c-array (length f) :ushort :initial-contents f)))))
      (if stream
          (if gpu-array              
              (values (list verts index) 
                      (cgl:make-vertex-stream verts :index-array index))
              (error "Cannot create stream without also creating a gpu-array"))
          (list verts index)))))

(defun primitive-data (type &key (size 1.0) (normals t) (tex-coords t))
  (case type
    (:plain (plain-data :size size :normals normals :tex-coords tex-coords))
    ((:box :cube) (box-data :width size :height size :depth size 
                            :normals normals :tex-coords tex-coords))
    (:sphere (sphere-data :radius size :normals normals :tex-coords tex-coords))
    (t (error "Do not have data for that primitive"))))

(defun plain-data (&key (size 1.0) (normals t) (tex-coords t))
  (list (list `(,(v! (- size) (- size) 0.0) 	
                    ,@(when normals `(,(v! 0.0 0.0 1.0)))
                    ,@(when tex-coords `(,(v! 0.0 1.0)))) 			
              `(,(v! size (- size) 0.0) 
                    ,@(when normals `(,(v! 0.0 0.0 1.0)))
                    ,@(when tex-coords `(,(v! 1.0 1.0))))
              `(,(v! size size 0.0)
                    ,@(when normals `(,(v! 0.0 0.0 1.0)))
                    ,@(when tex-coords `(,(v! 1.0 0.0))))
              `(,(v! (- size) size 0.0)
                    ,@(when normals `(,(v! 0.0 0.0 1.0)))
                    ,@(when tex-coords `(,(v! 0.0 0.0)))))
        nil))

(defun box-data (&key (width 1.0) (height 1.0) (depth 1.0)
                   (normals t) (tex-coords t))
  (let ((width (/ width 2.0))
        (height (/ height 2.0))
        (depth (/ depth 2.0)))
    ;; [TODO] why is each side a seperate list?
    (list (list  `(,(v! (- width) (- height) depth)
                       ,@(when normals `(,(v! 0.0 0.0 1.0)))
                       ,@(when tex-coords `(,(v! 0.0 1.0)))) 
                 `(,(v! width (- height) depth)
                       ,@(when normals `(,(v! 0.0 0.0 1.0)))
                       ,@(when tex-coords `(,(v! 1.0 1.0))))
                 `(,(v! width height depth)
                       ,@(when normals `(,(v! 0.0 0.0 1.0)))
                       ,@(when tex-coords `(,(v! 1.0 0.0))))
                 `(,(v! (- width) height depth)
                       ,@(when normals `(,(v! 0.0 0.0 1.0)))
                       ,@(when tex-coords `(,(v! 0.0 0.0))))
                 `(,(v! width (- height) (- depth))
                       ,@(when normals `(,(v! 0.0 0.0 -1.0)))
                       ,@(when tex-coords `(,(v! 0.0 1.0))))
                 `(,(v! (- width) (- height) (- depth))
                       ,@(when normals `(,(v! 0.0 0.0 -1.0)))
                       ,@(when tex-coords `(,(v! 1.0 1.0))))
                 `(,(v! (- width) height (- depth))
                       ,@(when normals `(,(v! 0.0 0.0 -1.0)))
                       ,@(when tex-coords `(,(v! 1.0 0.0))))
                 `(,(v! width height (- depth))
                       ,@(when normals `(,(v! 0.0 0.0 -1.0)))
                       ,@(when tex-coords `(,(v! 0.0 0.0))))
                 `(,(v! (- width) (- height) (- depth))
                       ,@(when normals `(,(v! -1.0 0.0 0.0)))
                       ,@(when tex-coords `(,(v! 0.0 1.0))))
                 `(,(v! (- width) (- height) depth)
                       ,@(when normals `(,(v! -1.0 0.0 0.0)))
                       ,@(when tex-coords `(,(v! 1.0 1.0))))
                 `(,(v! (- width) height depth)
                       ,@(when normals `(,(v! -1.0 0.0 0.0)))
                       ,@(when tex-coords `(,(v! 1.0 0.0))))
                 `(,(v! (- width) height (- depth))
                       ,@(when normals `(,(v! -1.0 0.0 0.0)))
                       ,@(when tex-coords `(,(v! 0.0 0.0))))
                 `(,(v! width (- height) depth)
                       ,@(when normals `(,(v! 1.0 0.0 0.0)))
                       ,@(when tex-coords `(,(v! 0.0 1.0))))
                 `(,(v! width (- height) (- depth))
                       ,@(when normals `(,(v! 1.0 0.0 0.0)))
                       ,@(when tex-coords `(,(v! 1.0 1.0))))
                 `(,(v! width height (- depth))
                       ,@(when normals `(,(v! 1.0 0.0 0.0)))
                       ,@(when tex-coords `(,(v! 1.0 0.0))))
                 `(,(v! width height depth)
                       ,@(when normals `(,(v! 1.0 0.0 0.0)))
                       ,@(when tex-coords `(,(v! 0.0 0.0))))
                 `(,(v! (- width) height depth)
                       ,@(when normals `(,(v! 0.0 1.0 0.0)))
                       ,@(when tex-coords `(,(v! 0.0 1.0))))
                 `(,(v! width height depth)
                       ,@(when normals `(,(v! 0.0 1.0 0.0)))
                       ,@(when tex-coords `(,(v! 1.0 1.0))))
                 `(,(v! width height (- depth))
                       ,@(when normals `(,(v! 0.0 1.0 0.0)))
                       ,@(when tex-coords `(,(v! 1.0 0.0))))
                 `(,(v! (- width) height (- depth))
                       ,@(when normals `(,(v! 0.0 1.0 0.0)))
                       ,@(when tex-coords `(,(v! 0.0 0.0))))
                 `(,(v! (- width) (- height) (- depth))
                       ,@(when normals `(,(v! 0.0 -1.0 0.0)))
                       ,@(when tex-coords `(,(v! 0.0 1.0))))
                 `(,(v! width (- height) (- depth))
                       ,@(when normals `(,(v! 0.0 -1.0 0.0)))
                       ,@(when tex-coords `(,(v! 1.0 1.0))))
                 `(,(v! width (- height) depth)
                       ,@(when normals `(,(v! 0.0 -1.0 0.0)))
                       ,@(when tex-coords `(,(v! 1.0 0.0))))
                 `(,(v! (- width) (- height) depth)
                       ,@(when normals `(,(v! 0.0 -1.0 0.0)))
                       ,@(when tex-coords `(,(v! 0.0 0.0)))))
          (list 0 1 2 0 2 3 4 5 6 4 6 7 8 9 10 8 10 11 12 13 14 12 14 15 16 17
                18 16 18 19 20 21 22 20 22 23))))

(defun sphere-data (&key (radius 1.0) (lines-of-latitude 10)
                      (lines-of-longitude 10) (normals t) (tex-coords t))
  (declare ((unsigned-byte 8) lines-of-longitude lines-of-latitude))
  ;; latitude  -  horizontal
  ;; longitude -  vertical
  (let ((faces (make-array (* 6 lines-of-latitude (* (1+ lines-of-longitude)))))
        (lat-angle (/ +pi+ lines-of-latitude))
        (lon-angle (/ (* 2.0 +pi+) lines-of-longitude))
        (f-index 0) (v-index 0))
    (list (loop :for lat :upto lines-of-latitude :append
             (let* ((part (* lat lat-angle))
                    (carry (* radius (sin part)))
                    (y (* radius (cos part))))
               (loop :for lon :upto (1- lines-of-longitude) :collect
                  (let* ((part (* lon lon-angle))
                         (x (* carry (sin part)))
                         (z (* carry (cos part)))
                         (pos (v! x y z)))
                    (when (not (eql lat lines-of-latitude))
                      (let ((part (+ v-index lines-of-longitude)))
                        (setf (aref faces f-index) (1+ part)
                              (aref faces (+ f-index 1))  v-index
                              (aref faces (+ f-index 2)) part
                              (aref faces (+ f-index 3)) (1+ part)
                              (aref faces (+ f-index 4)) (1+ v-index)
                              (aref faces (+ f-index 5)) v-index
                              f-index (+ 6 f-index)
                              v-index (1+ v-index))))
                    `(,(v3:v* pos radius)
                       ,@(when normals `(,(v3:normalize pos)))
                       ,@(when tex-coords
                               `(,(v! (/ lon lines-of-longitude)
                                      (/ lat lines-of-latitude)))))))))
          (coerce faces 'list))))
