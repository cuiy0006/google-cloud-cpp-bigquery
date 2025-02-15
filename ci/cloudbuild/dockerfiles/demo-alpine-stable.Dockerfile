# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM alpine:3.20
ARG NCPU=4

## [BEGIN packaging.md]

# Install the minimal development tools, libcurl, and OpenSSL:

# ```bash
RUN apk update && \
    apk add bash ca-certificates cmake curl git \
        gcc g++ make tar unzip zip zlib-dev
# ```

# Alpine's version of `pkg-config` (https://github.com/pkgconf/pkgconf) is slow
# when handling `.pc` files with lots of `Requires:` deps, which happens with
# Abseil, so we use the normal `pkg-config` binary, which seems to not suffer
# from this bottleneck. For more details see
# https://github.com/pkgconf/pkgconf/issues/229 and
# https://github.com/googleapis/google-cloud-cpp/issues/7052

# ```bash
WORKDIR /var/tmp/build/pkgconf
RUN curl -fsSL https://distfiles.ariadne.space/pkgconf/pkgconf-2.2.0.tar.gz | \
    tar -xzf - --strip-components=1 && \
    ./configure --prefix=/usr && \
    make -j ${NCPU:-4} && \
    make install && \
    cd /var/tmp && rm -fr build
# ```

# The following steps will install libraries and tools in `/usr/local`. By
# default, pkgconf does not search in these directories. We need to explicitly
# set the search path.

# ```bash
ENV PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/lib/pkgconfig
# ```

# #### Dependencies

# The versions of Abseil, Protobuf, gRPC, OpenSSL, and nlohmann-json included
# with Alpine >= 3.19 meet `google-cloud-cpp`'s requirements. We can simply
# install the development packages

# ```bash
RUN apk update && \
    apk add abseil-cpp-dev crc32c-dev c-ares-dev curl-dev grpc-dev \
        protobuf-dev ninja nlohmann-json openssl-dev re2-dev
# ```

# #### opentelemetry-cpp

# ```bash
WORKDIR /var/tmp/build/opentelemetry-cpp
RUN curl -fsSL https://github.com/open-telemetry/opentelemetry-cpp/archive/v1.18.0.tar.gz | \
    tar -xzf - --strip-components=1 && \
    cmake \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=yes \
        -DWITH_EXAMPLES=OFF \
        -DWITH_ABSEIL=ON \
        -DBUILD_TESTING=OFF \
        -DOPENTELEMETRY_INSTALL=ON \
        -DOPENTELEMETRY_ABI_VERSION_NO=2 \
        -S . -B cmake-out && \
    cmake --build cmake-out --target install -- -j ${NCPU:-4}
# ```

# #### apache-arrow
WORKDIR /var/tmp/build/arrow
RUN curl -fsSL https://github.com/apache/arrow/archive/apache-arrow-18.1.0.tar.gz | \
    tar -xzf - --strip-components=1 && \
    cmake \
      -GNinja -S cpp -B cmake-out \
      --preset ninja-release-minimal \
      -DARROW_JEMALLOC=OFF \
      -DBUILD_SHARED_LIBS=yes \
      -DARROW_BUILD_STATIC=ON  && \
    cmake --build cmake-out --target install
# ```

# #### google-cloud-cpp
WORKDIR /var/tmp/build/google-cloud-cpp
RUN curl -fsSL https://github.com/googleapis/google-cloud-cpp/archive/v2.35.0.tar.gz | \
    tar -xzf - --strip-components=1 && \
    cmake \
      -GNinja -S . -B cmake-out \
      -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_SHARED_LIBS=yes \
      -DBUILD_TESTING=OFF \
      -DGOOGLE_CLOUD_CPP_WITH_MOCKS=OFF \
      -DGOOGLE_CLOUD_CPP_ENABLE_EXAMPLES=OFF \
      -DGOOGLE_CLOUD_CPP_ENABLE=bigquery,bigquerycontrol,opentelemetry && \
    cmake --build cmake-out --target install
# ```

## [DONE packaging.md]

# Speed up the CI builds using sccache.
WORKDIR /var/tmp/sccache
RUN curl -fsSL https://github.com/mozilla/sccache/releases/download/v0.8.2/sccache-v0.8.2-x86_64-unknown-linux-musl.tar.gz | \
    tar -zxf - --strip-components=1 && \
    mkdir -p /usr/local/bin && \
    mv sccache /usr/local/bin/sccache && \
    chmod +x /usr/local/bin/sccache
