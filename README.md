# zig-prometheus-exporter-example

## Overview
Prometheus Exporter examples implemented in Zig.

The examples use [zig-prometheus](https://github.com/vrischmann/zig-prometheus)
to implement simple [prometheus http exporter server](https://prometheus.io/docs/instrumenting/writing_exporters/).

## Examples

| Name                    | Description |
|-------------------------|-------------|
| [std](src/std_main.zig) | Example implemented by [std.http.Server](https://ziglang.org/documentation/master/std/#std.http.Server) |
| [zap](src/zap_main.zig) | Example implemented by [zap lib](https://github.com/zap-zig/zap) |

## Usage
 * Install [zig >= 0.14](https://ziglang.org/download/)

 * Build Only.
```sh
zig build
```
