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
