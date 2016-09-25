import gab.opencv.*;
import org.opencv.imgproc.Imgproc;
import org.opencv.core.Mat;
import org.opencv.core.MatOfInt;
import org.opencv.core.MatOfInt4;

import org.opencv.core.MatOfPoint;

import beads.*;
import org.jaudiolibs.beads.*;

import KinectPV2.*;

String collection = "edm";


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
Glide[] rGlides = new Glide[12];
Gain[] gains = new Gain[12];

Gain totalGain;
Reverb reverb;
Glide reverbGlide;
int reverbHand;
float reverbValue = 1.0;

SamplePlayer sp1, sp2;

float volume = 0.;


int lCool = 0;
int rCool = 0;
int cooldown = 30;

int bIndex = 0;
boolean stretching = false;
float lastdist = 0.;

int lIndex = 0;
int rIndex = 0;

pt lHand, rHand;
hand leftHand, rightHand;

Sample[] arr4;

boolean lPlaying = false;
boolean rPlaying = false;


float tileWidth, tileHeight;
float marginVert = 50;
float marginHori = 50;

//OPEN CV

int threshold = 10;
double polygonFactor = 1;

int maxD = 800;
int minD = 20;

void setup() {   
  size(512, 424, P3D);
  opencv = new OpenCV(this, 512, 424);
  smooth();
  tileWidth = (width - 2 * marginHori)/4;
  tileHeight = (height - 2 * marginVert)/3;

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
    rGlides[i] = new Glide(ac, 1., 30);
  }
  for (int i = 0; i < gains.length; i++) {
    gains[i] = new Gain(ac, 1);
    ac.out.addInput(gains[i]);
  }
  
  reverb = new Reverb(ac, 1);
  reverb.setSize(0.7);
  reverb.setDamping(0.5);
  reverbGlide = new Glide(ac, 0., 10);
  totalGain = new Gain(ac, 1, reverb);
  reverb.addInput(totalGain);
  ac.out.addInput(reverb);
  ac.start();

  leftHand = new hand();
  int pleft = 0;
  rightHand = new hand();
  int pright = 0;
}

void draw() {
  ambientLight(102, 102, 102);
  spotLight(255,255,255, width, height, 10, -1, 0, 0, PI/2, 2);
  volume = 0.;
  int sum = 0;
  for (int i = 0; i < gains.length; i++) {
    if (gains[i] != null) {
      volume += gains[i].getGain();
      sum++;
    }
  }
  volume /= sum;
  noFill();
  stroke(255,255,255);
  strokeWeight(3);
  ellipse(volume * 50, volume * 50, width/2, height/2);
  float fov = PI/2.5; 
  float cameraZ = (height/2.0) / tan(fov/2.0); 
  perspective(fov, float(width)/float(height), cameraZ/2.0, cameraZ*2.0); 
  background(color(volume * 255, volume * 100, 255-(volume * 100), volume * 200));
  if (stretching) {
    background(color(volume * 100, volume * 100, volume * 100));
  }
  if (loaded) {
    depthImage = kinect.getDepthImage();
    //image(kinect.getPointCloudDepthImage(), 0,0);

    opencv.loadImage(kinect.getPointCloudDepthImage());
    opencv.threshold(threshold);
    opencv.blur(3);
    //PImage dst = opencv.getOutput();
    //image(dst, 0, 0);



    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 4; j++) {
        stroke(color(255, 255, 255));
        noFill();
        
        if (playing[i*4+j]) {
          strokeWeight(3);
          float volume = gains[i*4+j].getGain();
          stroke(color(255 - 100 * volume,255 * volume,255));
          noFill();
          float transX = j * tileWidth + tileWidth/2 + marginHori;
          float transY = i * tileHeight + tileHeight/2 + marginVert;
          float transZ = - (gains[i*4+j].getGain() - 0.8) * 50;
          translate(transX, transY, transZ);
          box(tileWidth, tileHeight, 30);
          translate(-transX, -transY, -transZ);
        } else {
          strokeWeight(1);
          rect(j * tileWidth + marginHori, i * tileHeight + marginVert, tileWidth, tileHeight);
        }
        fill(color(255, 255, 255));
        text((i * 4 + j), j * tileWidth + marginHori + 15, i * tileHeight + marginVert + 15);
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
      int rX = floor((rHand.pos.x - marginHori)/tileWidth);
      int rY = floor((rHand.pos.y - marginVert)/tileHeight);

      int lX = floor((lHand.pos.x - marginHori)/tileWidth);
      int lY = floor((lHand.pos.y - marginVert)/tileHeight);
      
      
      rIndex = abs(rX + rY * 4);
      lIndex = abs(lX + lY * 4);
      
      if (rIndex > 11) rIndex = 11;
      if (lIndex > 11) lIndex = 11;
      fill(color(255, 255, 255));
      text(rIndex, rHand.pos.x + 15, rHand.pos.y);
      text(lIndex, lHand.pos.x + 15, lHand.pos.y);
      
      if (!stretching && lIndex == rIndex && playing[lIndex] && (skeleton.getLeftHandState() == 3 || skeleton.getRightHandState() == 3)) {
        bIndex = lIndex;
        stretching = true;
        lastdist = dist(lHand, rHand);
        println("stretching");
      }
      if (stretching) {
        if (!(skeleton.getLeftHandState() == 3) && !(skeleton.getRightHandState() == 3)) {
          stretching = false;
          println("stopped stretching");
        } else {
          rGlides[bIndex].setValue(dist(lHand, rHand)/200);
        }
      }
      if (!stretching) {
        if (lHand.pos.x > marginHori
        && lHand.pos.x < width - marginHori
        && lHand.pos.y > marginVert
        && lHand.pos.y < height - marginVert) {
          if (skeleton.getLeftHandState() == 3 && lCool > cooldown) {
            lCool = 0;
            if (playing[lIndex]) {
              sPlayers[lIndex].kill();
              rGlides[lIndex].setValue(1.);
              playing[lIndex] = false;
            } else {
              sPlayers[lIndex] = new SamplePlayer(ac, samples.get(lIndex));
              sPlayers[lIndex].setLoopCrossFade(0.1);
              sPlayers[lIndex].setLoopType(SamplePlayer.LoopType.LOOP_FORWARDS);
              sPlayers[lIndex].setKillOnEnd(false);
              sPlayers[lIndex].setRate(rGlides[lIndex]);
              sPlayers[lIndex].start();
              playing[lIndex] = true;
              gains[lIndex].addInput(sPlayers[lIndex]);
              totalGain.addInput(sPlayers[lIndex]);
            }
          }
        } else {
          if (lHand.pos.x < marginHori
          && lHand.pos.y > marginVert
          && lHand.pos.y < height - marginVert) {
            lHand.pos.x = 30;
            reverbValue = 1000 * (1 - mapValue(marginVert, lHand.pos.y, height - marginVert));
            reverb.setValue(reverbValue);
            println(reverbValue);
          }
        }
        if (rHand.pos.x > marginHori
        && rHand.pos.x < width - marginHori
        && rHand.pos.y > marginVert
        && rHand.pos.y < height - marginVert) {
        if (skeleton.getRightHandState() == 3 && rCool > cooldown) {
          rCool = 0;
          println("right hand close: " + rIndex);
          if (playing[rIndex]) {
            sPlayers[rIndex].kill();
            rGlides[rIndex].setValue(1.);
            playing[rIndex] = false;
          } else {
            sPlayers[rIndex] = new SamplePlayer(ac, samples.get(rIndex));
            sPlayers[rIndex].setLoopCrossFade(0.1);
            sPlayers[rIndex].setLoopType(SamplePlayer.LoopType.LOOP_FORWARDS);
            sPlayers[rIndex].setKillOnEnd(false);
            sPlayers[rIndex].setRate(rGlides[rIndex]);
            sPlayers[rIndex].start();
            playing[rIndex] = true;
            gains[rIndex].addInput(sPlayers[rIndex]);
            totalGain.addInput(sPlayers[rIndex]);
          }
        }
      }
      if (playing[lIndex]) {
          gains[lIndex].setGain((lDepth-0.75)*10);
        }
        if (playing[rIndex]) {
          gains[rIndex].setGain((rDepth-0.75)*10);
        }
      if (stretching) {
        edge e = new edge(lHand, rHand);
        e.show();
      }
     }
      

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
  
  drawReverb();
}

void drawReverb() {
  noFill();
  stroke(color(255,255,255));
  strokeWeight(1);
  rect(30,marginVert, 10, height - 2 * marginVert);
  float rectHeight = mapValue(0.,reverbValue / 1000, height - 2*marginVert);
  strokeWeight(3);
  rect(30,marginVert + (height - (2 * marginVert)) - rectHeight, 10, rectHeight);
  stroke(0);
  fill(color(255,255,255));
  text(reverbValue, 20, marginVert - 10);
  
}

void drawBody(KJoint[] joints) {
  for (KJoint j : joints) {
    stroke(1);
    fill(color(255, 0, 0));
    ellipse(j.getX(), j.getY(), 5, 5);
  }
}
void drawHandState(KJoint joint) {
  pointLight(255,255,255,joint.getX(), joint.getY(), 10);
  fill(color(255,255,255));
  translate(joint.getX(), joint.getY(), 0);
  if (stretching) {
    fill(color(255,255,0));
    sphere(30);
  } else {
    sphere(15);
  }
  translate(-joint.getX(), -joint.getY(), 0);
  fill(color(255, 255, 255));
  color c = depthImage.get((int)joint.getX(), (int)joint.getY());
}

float mapValue(float start, float val, float end) {
  return (val - start)/(end - start);
}