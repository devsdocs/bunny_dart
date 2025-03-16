void errorPrint(String message, {bool isPrint = false}) {
  if (!isPrint) return;
  // ignore: avoid_print
  print(message);
}
