// Gallery matrix bucket 0 of 4 — see gallery_matrix_runner.dart (modulo bucketing so sharding
// parallelizes the former whale file). 画廊矩阵取模桶 0/4,拆鲸鱼供分片并行,见 runner。
import 'gallery_matrix_runner.dart';

void main() => runGalleryMatrix(bucket: 0, buckets: 4);
