# zig-prometheus-exporter-example

## Overview
Prometheus Exporter examples implemented in Zig.

The examples use [zig-prometheus](https://github.com/vrischmann/zig-prometheus)
to implement simple [prometheus http exporter server](https://prometheus.io/docs/instrumenting/writing_exporters/).

## Examples

| Name                                  | Description |
|---------------------------------------|-------------|
| [std](src/std_main.zig)               | Example implemented by [std.http.Server](https://ziglang.org/documentation/master/std/#std.http.Server) |
| [zap-raw](src/zap_raw_main.zig)       | Example implemented by [zap lib](https://github.com/zigzap/zap) without Zap.router |
| [zap-router](src/zap_router_main.zig) | Example implemented by [zap lib](https://github.com/zigzap/zap) with Zap.router |
| [http.zig](src/httpz_main.zig)        | Example implemented by [http.zig](https://github.com/karlseguin/http.zig) |

## Usage
### Preparation
   Install [zig >= 0.14](https://ziglang.org/download/)

### Build examples
   ```sh
   zig build
   ```
### Run examples
   Use `zig build run-xxx` command. See help of `zig build`.
   Access `http://localhost:3000/metrics`.
   ```sh
   Usage: zig build [steps] [options]

   Steps:
     install (default)            Copy build artifacts to prefix path
     uninstall                    Remove build artifacts from prefix path
     run-std                      Run std.http app
     run-zap-raw                  Run zap app without Zap.router
     run-zap-router               Run zap app with Zap.router
     run-httpz                    Run httpz apps
     test                         Run unit tests
   ```
