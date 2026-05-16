// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_uploadcare/otel_uploadcare.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_uploadcare-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('multipart upload records parts + mime + bytes', () async {
    await tracedUploadcare<String>(
      operation: 'upload.multipart.complete',
      api: 'upload',
      invoke: () async => const UploadcareCallResult(
        value: 'ok',
        result: UploadcareResult(
          uuid: 'uuid-1',
          api: 'upload',
          mimeType: 'video/mp4',
          bytes: 524288000,
          partCount: 10,
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(
      spans.findSpanByName('uploadcare upload.multipart.complete')!,
    );
    expect(a['uploadcare.api'], 'upload');
    expect(a['uploadcare.uuid'], 'uuid-1');
    expect(a['uploadcare.mime_type'], 'video/mp4');
    expect(a['uploadcare.part_count'], 10);
  });

  test('addon execute records addon name', () async {
    await tracedUploadcare<String>(
      operation: 'addons.remove_bg.execute',
      invoke: () async => const UploadcareCallResult(
        value: 'ok',
        result: UploadcareResult(addon: 'remove_bg'),
      ),
    );
    final a = attrsOf(
      spans.findSpanByName('uploadcare addons.remove_bg.execute')!,
    );
    expect(a['uploadcare.addon'], 'remove_bg');
  });

  test('suppression skips spans', () async {
    await runWithoutUploadcareInstrumentationAsync(() async {
      await tracedUploadcare<String>(
        operation: 'files.list',
        invoke: () async => const UploadcareCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('uploadcare '), isEmpty);
  });
}
