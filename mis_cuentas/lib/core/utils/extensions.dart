
extension StringExtensions on String {
  String take(int n) {
    if (this.length <= n) return this;
    return this.substring(0, n);
  }
}
