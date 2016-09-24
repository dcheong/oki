import gab.opencv.*;
import org.opencv.imgproc.Imgproc;
import org.opencv.core.Mat;
import org.opencv.core.MatOfInt;
import org.opencv.core.MatOfInt4;

import org.opencv.core.MatOfPoint;

import beads.*;
import org.jaudiolibs.beads.*;

import KinectPV2.*;

String collection = "tropical";


KinectPV2 kinect;
OpenCV opencv;

int depthWidth, depthHeight;
PImage depthImage;

//BEADS 

boolean loaded = false;

ArrayList<Sample> samples;
ArrayList<String> labels;
AudioContext ac;
SamplePlayer[] sPlayers = new SamplePlayer[12];
boolean[] playing = new boolean[12];
boolean[] looping = new boolean[12];
Glide[] vGlides = new Glide[12];
Gain[] gains = new Gain[12];
SamplePlayer sp1, sp2;

float volume = 0.;


int lCool = 0;
int rCool = 0;
int cooldown = 30;

int lIndex = 0;
int rIndex = 0;

pt lHand, rHand;
hand leftHand, rightHand;

Sample[] arr4;

boolean lPlaying = false;
boolean rPlaying = false;


float tileWidth, tileHeight;

//OPEN CV

int threshold = 10;
double polygonFactor = 1;

int maxD = 1000;
int minD = 20;

void setup() {   
  size(512, 424, P3D);
  opencv = new OpenCV(this, 512, 424);
  smooth();
  tileWidth = width/4;
  tileHeight = height/3;

  kinect = new KinectPV2(this);   
  kinect.enableDepthImg(true);
  kinect.enableBodyTrackImg(true);
  kinect.enablePointCloud(true);
  kinect.enableSkeletonDepthMap(true);
  kinect.setLowThresholdPC(minD);
  kinect.setHighThresholdPC(maxD);
  kinect.init();

  samples = new ArrayList<Sample>();
  load4(collection);
  ac = new AudioContext();
  for (int i = 0; i < vGlides.length; i++) {
    vGlides[i] = new Glide(ac, 0., 10);
  }
  for (int i = 0; i < gains.length; i++) {
    gains[i] = new Gain(ac, 1);
    ac.out.addInput(gains[i]);
  }
  ac.start();

  leftHand = new hand();
  int pleft = 0;
  rightHand = new hand();
  int pright = 0;
}  
void draw() {
  lights();
  volume = 0.;
  int sum = 0;
  for (int i = 0; i < gains.length; i++) {
    if (gains[i] != null) {
      volume += gains[i].getGain();
      sum++;
    }
  }
  volume /= sum;
  float fov = PI/2.5; 
  float cameraZ = (height/2.0) / tan(fov/2.0); 
  perspective(fov, float(width)/float(height), cameraZ/2.0, cameraZ*2.0); 
  background(color(volume * 255, volume * 100, 255-(volume * 100), volume * 200));
  if (loaded) {
    depthImage = kinect.getDepthImage();
    //image(kinect.getPointCloudDepthImage(), 0,0);

    opencv.loadImage(kinect.getPointCloudDepthImage());
    opencv.threshold(threshold);
    opencv.blur(3);
    PImage dst = opencv.getOutput();
    //image(dst, 0, 0);



    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 4; j++) {
        stroke(color(255, 255, 255));
        noFill();
        if (i * 4 + j == lIndex || i*4 + j == rIndex) {
        }
        if (playing[i*4+j]) {
          strokeWeight(3);
          stroke(color(255,255,255));
          float transX = j * tileWidth + tileWidth/2;
          float transY = i * tileHeight + tileHeight/2;
          float transZ = - (gains[i*4+j].getGain() - 0.8) * 50;
          translate(transX, transY, transZ);
          box(tileWidth, tileHeight, 30);
          translate(-transX, -transY, -transZ);
        } else {
          strokeWeight(1);
          rect(j * tileWidth, i * tileHeight, tileWidth, tileHeight);
        }
        fill(color(255, 255, 255));
        text((i * 4 + j), j * tileWidth + 15, i * tileHeight + 15);
      }
    }
    //get the skeletons as an Arraylist of KSkeletons
    ArrayList<KSkeleton> skeletonArray =  kinect.getSkeletonDepthMap();
    //get the skeleton as an Arraylist mapped to the color frame
    //ArrayList<KSkeleton> skeletonArray =  kinect.getSkeletonColorMap();
    //individual joints
    if (skeletonArray.size() != 0) {

      KSkeleton skeleton = (KSkeleton) skeletonArray.get(0);
      KJoint[] joints = skeleton.getJoints();
      color col  = skeleton.getIndexColor();
      fill(col);
      stroke(col);
      fill(0);
      stroke(color(255, 255, 255));
      KJoint left = joints[KinectPV2.JointType_HandLeft];
      KJoint right = joints[KinectPV2.JointType_HandRight];
      float lDepth = (255 - alpha(depthImage.get((int)left.getX(), (int)left.getY()))) / 255.;
      float rDepth = (255 - alpha(depthImage.get((int)right.getX(), (int)right.getY()))) / 255.;
      lHand = new pt(joints[KinectPV2.JointType_HandLeft].getX(), 
        joints[KinectPV2.JointType_HandLeft].getY());
      rHand = new pt(joints[KinectPV2.JointType_HandRight].getX(), 
        joints[KinectPV2.JointType_HandRight].getY());
      int rX = floor(rHand.pos.x/tileWidth);
      int rY = floor(rHand.pos.y/tileHeight);

      int lX = floor(lHand.pos.x/tileWidth);
      int lY = floor(lHand.pos.y/tileHeight);

      rIndex = abs(rX + rY * 4);
      lIndex = abs(lX + lY * 4);
      if (rIndex > 11) rIndex = 11;
      if (lIndex > 11) lIndex = 11;
      fill(color(255, 255, 255));
      text(rIndex, rHand.pos.x + 15, rHand.pos.y);
      text(lIndex, lHand.pos.x + 15, lHand.pos.y);

      if (skeleton.getLeftHandState() == 3 && lCool > cooldown) {
        lCool = 0;
        println("left hand close: " + lIndex);
        if (playing[lIndex]) {
          sPlayers[lIndex].kill();
          playing[lIndex] = false;
        } else {
          sPlayers[lIndex] = new SamplePlayer(ac, samples.get(lIndex));
          sPlayers[lIndex].setLoopCrossFade(0.1);
          sPlayers[lIndex].setLoopType(SamplePlayer.LoopType.LOOP_FORWARDS);
          sPlayers[lIndex].setKillOnEnd(false);
          sPlayers[lIndex].start();
          playing[lIndex] = true;
          gains[lIndex].addInput(sPlayers[lIndex]);
        }
      }
      if (skeleton.getRightHandState() == 3 && rCool > cooldown) {
        rCool = 0;
        println("right hand close: " + rIndex);
        if (playing[rIndex]) {
          sPlayers[rIndex].kill();
          playing[rIndex] = false;
        } else {
          sPlayers[rIndex] = new SamplePlayer(ac, samples.get(rIndex));
          sPlayers[rIndex].setLoopCrossFade(0.1);
          sPlayers[rIndex].setLoopType(SamplePlayer.LoopType.LOOP_FORWARDS);
          sPlayers[rIndex].setKillOnEnd(false);
          sPlayers[rIndex].start();
          playing[rIndex] = true;
          gains[rIndex].addInput(sPlayers[rIndex]);
        }
      }
      if (playing[lIndex]) {
        gains[lIndex].setGain((lDepth-0.75)*10);
        println(lDepth);
      }
      if (playing[rIndex]) {
        gains[rIndex].setGain(rDepth);
      }

      //if (lIndex != lSample && skeleton.getLeftHandState() == 3) {
      //  println("new lIndex");
      //  sp1.setSample(samples.get(lIndex));
      //  lSample = lIndex;
      //  sp1.start();
      //}

      //if (rIndex != rSample && skeleton.getRightHandState() == 3) {
      //  println("new rIndex");
      //  sp2.setSample(samples.get(rIndex));
      //  rSample = rIndex;
      //  sp2.start();
      //}
      edge e = new edge(lHand, rHand);
      e.show();



      drawHandState(joints[KinectPV2.JointType_HandRight]);
      drawHandState(joints[KinectPV2.JointType_HandLeft]);
    }

    ArrayList<Contour> contours = opencv.findContours(false, false);
    if (contours.size() > 0 && lHand != null && rHand != null) {
      for (Contour contour : contours) {
        contour.setPolygonApproximationFactor(polygonFactor);
        if (contour.containsPoint((int)lHand.pos.x, (int)lHand.pos.y)) {
          leftHand.updateKPoint(lHand);
          leftHand.updateHull(contour.getPolygonApproximation());
          leftHand.defects();
          leftHand.show();
        }
        if (contour.containsPoint((int)rHand.pos.x, (int)rHand.pos.y)) {
          rightHand.updateKPoint(rHand);
          rightHand.updateHull(contour.getPolygonApproximation());
          rightHand.defects();
          rightHand.show();
        }
      }

      if (leftHand.hull != null && lHand != null) {
        fill(color(255, 255, 255));
        text(leftHand.hull.numPoints(), lHand.pos.x + 15, lHand.pos.y);
      }
      if (rightHand.hull != null && rHand != null) {
        fill(color(255, 255, 255));
        text(rightHand.hull.numPoints(), rHand.pos.x + 15, rHand.pos.y);
      }
    }

    lCool++;
    rCool++;
  }
}

void drawBody(KJoint[] joints) {
  for (KJoint j : joints) {
    stroke(1);
    fill(color(255, 0, 0));
    ellipse(j.getX(), j.getY(), 5, 5);
  }
}
void drawHandState(KJoint joint) {
  fill(color(255,255,255));
  translate(joint.getX(), joint.getY(), 0);
  sphere(15);
  translate(-joint.getX(), -joint.getY(), 0);
  fill(color(255, 255, 255));
  color c = depthImage.get((int)joint.getX(), (int)joint.getY());
}