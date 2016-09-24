
void load4(String collection) {
  File dir = new File(sketchPath("") + "sound/" + collection);
  String[] list = dir.list();
  println(list.length);
  try {
      for (String path : list) {
        println(path);
        samples.add(SampleManager.sample(sketchPath("") + "sound/" + collection + "/" + path));
      }
      loaded = true;
  } catch (Exception e) {
    println("failed to load sounds");
  }
}