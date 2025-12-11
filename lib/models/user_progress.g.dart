// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_progress.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserProgressAdapter extends TypeAdapter<UserProgress> {
  @override
  final int typeId = 1;

  @override
  UserProgress read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserProgress(
      dailyGoal: fields[0] as int,
      answeredToday: fields[1] as int,
      streak: fields[2] as int,
      lastPlayedDate: fields[3] as DateTime,
      targetCategory: fields[4] as String?,
      targetDate: fields[5] as DateTime?,
      notificationHour: fields[6] == null ? 18 : fields[6] as int,
      notificationMinute: fields[7] == null ? 0 : fields[7] as int,
      isDarkMode: fields[8] == null ? false : fields[8] as bool,
      userName: fields[9] == null ? '' : fields[9] as String,
      hiddenCategories:
          fields[10] == null ? [] : (fields[10] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, UserProgress obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.dailyGoal)
      ..writeByte(1)
      ..write(obj.answeredToday)
      ..writeByte(2)
      ..write(obj.streak)
      ..writeByte(3)
      ..write(obj.lastPlayedDate)
      ..writeByte(4)
      ..write(obj.targetCategory)
      ..writeByte(5)
      ..write(obj.targetDate)
      ..writeByte(6)
      ..write(obj.notificationHour)
      ..writeByte(7)
      ..write(obj.notificationMinute)
      ..writeByte(8)
      ..write(obj.isDarkMode)
      ..writeByte(9)
      ..write(obj.userName)
      ..writeByte(10)
      ..write(obj.hiddenCategories);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProgressAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
