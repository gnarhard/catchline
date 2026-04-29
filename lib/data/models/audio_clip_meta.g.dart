// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_clip_meta.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AudioClipMetaAdapter extends TypeAdapter<AudioClipMeta> {
  @override
  final typeId = 1;

  @override
  AudioClipMeta read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AudioClipMeta(
      id: fields[0] as String,
      durationMs: (fields[1] as num).toInt(),
      createdAtMs: (fields[2] as num).toInt(),
      mimeType: fields[3] as String,
      fileExt: fields[4] as String,
      label: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AudioClipMeta obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.durationMs)
      ..writeByte(2)
      ..write(obj.createdAtMs)
      ..writeByte(3)
      ..write(obj.mimeType)
      ..writeByte(4)
      ..write(obj.fileExt)
      ..writeByte(5)
      ..write(obj.label);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioClipMetaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
