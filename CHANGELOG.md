## 2.8.1

* chore(SocketManager): log the resolved query-parameter keys (keys only,
  no values — never leaks the token) on each connect, to confirm the auth
  query is attached in the running build.

## 2.8.0

* **BREAKING** refactor(SocketManager): drop the static `queryParameters`
  field — query parameters are now provided exclusively through the
  `queryBuilder` callback (built fresh on every (re)connect, like
  `headersBuilder`). Callers that passed static `queryParameters` should
  move those entries into `queryBuilder`. This keeps the auth token (and
  any other query) always fresh and avoids a stale snapshot captured at
  construction time. Aligns with `SseManager`'s `queryParametersBuilder`.

## 2.7.0

* feat(SocketManager): add optional `queryBuilder` callback — builds fresh
  query parameters on every (re)connect (mirrors `headersBuilder`). Lets a
  caller pass the auth token inside the WS URL itself as a reliable fallback
  to the `Authorization` header, which `dart:io` does not consistently send
  on reconnect. Eliminates the repeated 4001 reject/reconnect flapping seen
  on mobile after backgrounding. `headersBuilder` is untouched; the static
  `queryParameters` still works and is merged under the dynamic builder.

## 2.6.0

* deps: bump `file_picker` to `^12.0.0-beta.2` to drop the legacy
  `DKImagePickerController` chain (resolves SPM conflict with
  `image_cropper`'s `TOCropViewController 3.x`)
* deps: bump `package_info_plus` to `^10.1.0` and `device_info_plus`
  to `^13.1.0` to satisfy `win32 ^6.x` required by the new `file_picker`

## 0.0.1

* TODO: Describe initial release.
