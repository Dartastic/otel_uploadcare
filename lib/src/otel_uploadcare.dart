// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_uploadcare_suppression.dart';

const _tracerName = 'dartastic_otel_libs_uploadcare';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class UploadcareResult {
  const UploadcareResult({
    this.uuid,
    this.api,
    this.mimeType,
    this.bytes,
    this.partCount,
    this.fromUrl,
    this.cdnTransformations,
    this.addon,
    this.requestId,
    this.statusCode,
  });

  /// `uuid` returned for the uploaded file / group.
  final String? uuid;

  /// `upload` (upload.uploadcare.com) / `rest` (api.uploadcare.com) /
  /// `cdn` (ucarecdn.com) / `webhook`.
  final String? api;

  /// Detected mime type.
  final String? mimeType;

  /// File bytes.
  final int? bytes;

  /// Parts for multipart upload (Uploadcare bills per part for
  /// large-file uploads).
  final int? partCount;

  /// True for the `from_url` (URL-import) flow.
  final bool? fromUrl;

  /// Number of CDN transformations applied (`-/preview/`, `-/crop/`,
  /// `-/format/`, ...).
  final int? cdnTransformations;

  /// Add-on used: `aws_rekognition` / `aws_rekognition_moderation` /
  /// `clamav_virus_scan` / `remove_bg` / `uc_clamav`. Each metered
  /// separately.
  final String? addon;

  /// `X-Request-Id`.
  final String? requestId;

  final int? statusCode;
}

class UploadcareCallResult<T> {
  const UploadcareCallResult({required this.value, this.result});
  final T value;
  final UploadcareResult? result;
}

/// Wraps an Uploadcare API call in a CLIENT span. [operation] is one
/// of `upload.base`, `upload.from_url`, `upload.multipart.start`,
/// `upload.multipart.complete`, `files.list`, `files.info`,
/// `files.delete`, `files.store`, `groups.list`, `groups.info`,
/// `groups.create`, `webhooks.list`, `webhooks.create`,
/// `addons.aws_rekognition.execute`, `addons.uc_clamav.execute`,
/// `addons.remove_bg.execute`, `project.info`.
Future<T> tracedUploadcare<T>({
  required String operation,
  required Future<UploadcareCallResult<T>> Function() invoke,
  String? api,
}) async {
  if (uploadcareInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'uploadcare',
    'rpc.method': operation,
    'uploadcare.operation': operation,
  };
  if (api != null) m['uploadcare.api'] = api;

  final span = _tracer().startSpan(
    'uploadcare $operation',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.uuid != null) {
        extras.add(OTel.attributeString(
          'uploadcare.uuid',
          r.result!.uuid!,
        ));
      }
      if (r.result!.api != null) {
        extras.add(OTel.attributeString(
          'uploadcare.api',
          r.result!.api!,
        ));
      }
      if (r.result!.mimeType != null) {
        extras.add(OTel.attributeString(
          'uploadcare.mime_type',
          r.result!.mimeType!,
        ));
      }
      if (r.result!.bytes != null) {
        extras.add(OTel.attributeInt(
          'uploadcare.bytes',
          r.result!.bytes!,
        ));
      }
      if (r.result!.partCount != null) {
        extras.add(OTel.attributeInt(
          'uploadcare.part_count',
          r.result!.partCount!,
        ));
      }
      if (r.result!.fromUrl != null) {
        extras.add(OTel.attributeBool(
          'uploadcare.from_url',
          r.result!.fromUrl!,
        ));
      }
      if (r.result!.cdnTransformations != null) {
        extras.add(OTel.attributeInt(
          'uploadcare.cdn_transformations',
          r.result!.cdnTransformations!,
        ));
      }
      if (r.result!.addon != null) {
        extras.add(OTel.attributeString(
          'uploadcare.addon',
          r.result!.addon!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTel.attributeString(
          'uploadcare.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTel.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Uploadcare HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
