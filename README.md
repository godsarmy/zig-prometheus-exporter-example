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
| [http.zig](src/httpz_main.zig) | Example implemented by [http.zig](https://github.com/karlseguin/zig-http) |

## Usage
 * Install [zig >= 0.14](https://ziglang.org/download/)

 * Build Only.
   ```sh
   zig build
   ```
 * Run examples
   Use `zig build run-xxx` command. See help of `zig build`.
   Access `http://localhost:3000/metrics`.
   ```sh
   Usage: zig build [steps] [options]

   Steps:
     install (default)            Copy build artifacts to prefix path
     uninstall                    Remove build artifacts from prefix path
     run-std                      Run std.http app
     run-zap                      Run zap apps
     run-httpz                    Run httpz apps
     test                         Run unit tests
   ```
