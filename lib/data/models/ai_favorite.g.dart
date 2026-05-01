// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_favorite.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AiFavoriteAdapter extends TypeAdapter<AiFavorite> {
  @override
  final typeId = 3;

  @override
  AiFavorite read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AiFavorite(
      style: fields[0] as String,
      text: fields[1] as String,
      createdAtMs: (fields[2] as num).toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, AiFavorite obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.style)
      ..writeByte(1)
      ..write(obj.text)
      ..writeByte(2)
      ..write(obj.createdAtMs);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiFavoriteAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
