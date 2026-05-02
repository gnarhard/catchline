// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ItemAdapter extends TypeAdapter<Item> {
  @override
  final typeId = 2;

  @override
  Item read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Item(
      id: fields[0] as String,
      kind: fields[1] as ItemKind,
      title: fields[2] as String,
      textBody: fields[3] as String,
      audioClips: (fields[4] as List).cast<AudioClipMeta>(),
      createdAtMs: (fields[5] as num).toInt(),
      updatedAtMs: (fields[6] as num).toInt(),
      deletedAtMs: (fields[7] as num?)?.toInt(),
      aiSynopsis: fields[8] as String?,
      aiRephrasings: (fields[9] as Map?)?.cast<String, String>(),
      aiFavorites: (fields[10] as List?)?.cast<AiFavorite>(),
      tag: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Item obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.kind)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.textBody)
      ..writeByte(4)
      ..write(obj.audioClips)
      ..writeByte(5)
      ..write(obj.createdAtMs)
      ..writeByte(6)
      ..write(obj.updatedAtMs)
      ..writeByte(7)
      ..write(obj.deletedAtMs)
      ..writeByte(8)
      ..write(obj.aiSynopsis)
      ..writeByte(9)
      ..write(obj.aiRephrasings)
      ..writeByte(10)
      ..write(obj.aiFavorites)
      ..writeByte(11)
      ..write(obj.tag);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
