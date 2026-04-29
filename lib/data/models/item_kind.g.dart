// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'item_kind.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ItemKindAdapter extends TypeAdapter<ItemKind> {
  @override
  final typeId = 0;

  @override
  ItemKind read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ItemKind.journal;
      case 1:
        return ItemKind.poem;
      case 2:
        return ItemKind.lyric;
      case 3:
        return ItemKind.phrase;
      default:
        return ItemKind.journal;
    }
  }

  @override
  void write(BinaryWriter writer, ItemKind obj) {
    switch (obj) {
      case ItemKind.journal:
        writer.writeByte(0);
      case ItemKind.poem:
        writer.writeByte(1);
      case ItemKind.lyric:
        writer.writeByte(2);
      case ItemKind.phrase:
        writer.writeByte(3);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemKindAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
