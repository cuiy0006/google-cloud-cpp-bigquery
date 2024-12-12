// Copyright 2024 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#ifndef GOOGLE_CLOUD_CPP_BIGQUERY_GOOGLE_CLOUD_BIGQUERY_UNIFIED_VERSION_H
#define GOOGLE_CLOUD_CPP_BIGQUERY_GOOGLE_CLOUD_BIGQUERY_UNIFIED_VERSION_H

#include "google/cloud/bigquery_unified/internal/version_info.h"
#include "google/cloud/internal/attributes.h"
#include "google/cloud/internal/port_platform.h"
#include <string>

#define GOOGLE_CLOUD_CPP_BIGQUERY_VCONCAT(Ma, Mi, Pa) v##Ma##_##Mi
#define GOOGLE_CLOUD_CPP_BIGQUERY_VEVAL(Ma, Mi, Pa) \
  GOOGLE_CLOUD_CPP_BIGQUERY_VCONCAT(Ma, Mi, Pa)
#define GOOGLE_CLOUD_CPP_BIGQUERY_NS                                       \
  GOOGLE_CLOUD_CPP_BIGQUERY_VEVAL(GOOGLE_CLOUD_CPP_BIGQUERY_VERSION_MAJOR, \
                                  GOOGLE_CLOUD_CPP_BIGQUERY_VERSION_MINOR, \
                                  GOOGLE_CLOUD_CPP_BIGQUERY_VERSION_PATCH)

/**
 * Versioned inline namespace that users should generally avoid spelling.
 *
 * The actual inline namespace name will change with each release, and if you
 * use it your code will be tightly coupled to a specific release. Omitting the
 * inline namespace name will make upgrading to newer releases easier.
 *
 * However, applications may need to link multiple versions of the Google Cloud
 * C++ Libraries, for example, if they link a library that uses an older
 * version of the libraries than they do. This namespace is inlined, so
 * applications can use `google::cloud::bigquery_unified::Foo` in their source,
 * but the symbols are versioned, i.e., the symbol becomes
 * `google::cloud::bigquery_unified::vXYZ::Foo`.
 */
#define GOOGLE_CLOUD_CPP_BIGQUERY_INLINE_NAMESPACE_BEGIN \
  inline namespace GOOGLE_CLOUD_CPP_BIGQUERY_NS {
#define GOOGLE_CLOUD_CPP_BIGQUERY_INLINE_NAMESPACE_END \
  } /* namespace GOOGLE_CLOUD_CPP_BIGQUERY_NS */

namespace google::cloud::bigquery_unified_internal {
auto constexpr kMaxMinorVersions = 100;
auto constexpr kMaxPatchVersions = 100;
}  // namespace google::cloud::bigquery_unified_internal

/**
 * Contains all the Google Cloud C++ BigQuery Library APIs.
 */
namespace google::cloud::bigquery_unified {
GOOGLE_CLOUD_CPP_BIGQUERY_INLINE_NAMESPACE_BEGIN

/**
 * The Google Cloud C++ BigQuery Client major version.
 *
 * @see https://semver.org/spec/v2.0.0.html for details.
 */
int constexpr version_major() {
  return GOOGLE_CLOUD_CPP_BIGQUERY_VERSION_MAJOR;
}

/**
 * The Google Cloud C++ BigQuery Client minor version.
 *
 * @see https://semver.org/spec/v2.0.0.html for details.
 */
int constexpr version_minor() {
  return GOOGLE_CLOUD_CPP_BIGQUERY_VERSION_MINOR;
}

/**
 * The Google Cloud C++ BigQuery Client patch version.
 *
 * @see https://semver.org/spec/v2.0.0.html for details.
 */
int constexpr version_patch() {
  return GOOGLE_CLOUD_CPP_BIGQUERY_VERSION_PATCH;
}

/**
 * The Google Cloud C++ BigQuery Client pre-release version.
 *
 * @see https://semver.org/spec/v2.0.0.html for details.
 */
constexpr char const* version_pre_release() {
  return GOOGLE_CLOUD_CPP_BIGQUERY_VERSION_PRE_RELEASE;
}

/// A single integer representing the Major/Minor/Patch version.
int constexpr version() {
  static_assert(version_minor() <
                    google::cloud::bigquery_unified_internal::kMaxMinorVersions,
                "version_minor() should be < kMaxMinorVersions");
  static_assert(version_patch() <
                    google::cloud::bigquery_unified_internal::kMaxPatchVersions,
                "version_patch() should be < kMaxPatchVersions");
  return google::cloud::bigquery_unified_internal::kMaxPatchVersions *
             (google::cloud::bigquery_unified_internal::kMaxMinorVersions *
                  version_major() +
              version_minor()) +
         version_patch();
}

/// The version as a string, in MAJOR.MINOR.PATCH[-PRE][+gitrev] format.
std::string version_string();

GOOGLE_CLOUD_CPP_BIGQUERY_INLINE_NAMESPACE_END
}  // namespace google::cloud::bigquery_unified

#endif  // GOOGLE_CLOUD_CPP_BIGQUERY_GOOGLE_CLOUD_BIGQUERY_UNIFIED_VERSION_H
