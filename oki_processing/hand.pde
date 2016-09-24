class hand {
  Contour hull;
  ArrayList<Integer> startIndices = new ArrayList();
  ArrayList<PVector> startPoints = new ArrayList();
  ArrayList<Integer> defectIndices = new ArrayList();
  ArrayList<PVector> defectPoints = new ArrayList();
  ArrayList<Float> depths = new ArrayList();
  pt kPoint;
  hand() {
  }
  hand(Contour hull, pt kPoint) {
    this.hull = hull;
    this.kPoint = kPoint;
  }
  void defects() {
    Contour convexHull = hull.getPolygonApproximation().getConvexHull();

    PVector hullCenter = new PVector(convexHull.getBoundingBox().x + convexHull.getBoundingBox().width/2, 
    convexHull.getBoundingBox().y + convexHull.getBoundingBox().height/2);
  
  
    MatOfInt conhull = new MatOfInt();
    MatOfPoint points = new MatOfPoint(hull.pointMat);
    Imgproc.convexHull(points, conhull);
  
    MatOfInt4 defects = new MatOfInt4();
    Imgproc.convexityDefects(points, conhull, defects );
  
    startPoints = new ArrayList<PVector>();
    defectPoints  = new ArrayList<PVector>();
    depths =  new ArrayList<Float>(); 
  
    startIndices = new ArrayList<Integer>();
    defectIndices = new ArrayList<Integer>();
    for (int i = 0; i < defects.height(); i++) {
  
      int startIndex = (int)defects.get(i, 0)[0];
      startIndices.add(startIndex);
      int defectIndex = (int)defects.get(i, 0)[2];
      defectIndices.add( defectIndex );
      
      PVector start = hull.getPoints().get(startIndex);
      PVector valley = hull.getPoints().get(defectIndex);
      float d = PVector.dist(start, valley);
      startPoints.add(hull.getPoints().get(startIndex));
      defectPoints.add(hull.getPoints().get(defectIndex));
      depths.add((float)defects.get(i, 0)[3]);
    }
    
  }
  void show() {
    stroke(255, 255, 255);
    fill(color(255,255,255,100));
    strokeWeight(3);
    hull.draw();
    //for (PVector p : defectPoints) {
    //  fill(color(255,0,0));
    //  ellipse(p.x, p.y, 3,3);
    //  line(p.x, p.y, kPoint.pos.x, kPoint.pos.y);
    //}
    //stroke(color(255,255,255));
    //for (PVector p: startPoints) {
    //  fill(color(0,255,0));
    //  ellipse(p.x, p.y, 3,3);
    //  line(p.x, p.y, kPoint.pos.x, kPoint.pos.y);
    //}
  }
  void updateKPoint(pt kPoint) {
    this.kPoint = kPoint;
  }
  void updateHull(Contour c) {
    this.hull = c;
  }
  int fingersUp() {
    return startPoints.size();
  }
}