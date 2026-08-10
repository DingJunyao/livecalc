/// 视野半径（km）→ 缩放级别，直接抄 web 商家地图的聚焦逻辑。
double radiusKmToZoom(double km) {
  if (km <= 1) return 14;
  if (km <= 2) return 13;
  if (km <= 5) return 12;
  if (km <= 10) return 11;
  if (km <= 20) return 10;
  if (km <= 50) return 9;
  return 8;
}
