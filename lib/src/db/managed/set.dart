import 'dart:collection';

import 'backing.dart';
import '../../http/serializable.dart';
import 'managed.dart';
import '../query/query.dart';

/// Instances of this type contain zero or more instances of [ManagedObject] and represent has-many relationships.
///
/// 'Has many' relationship properties in [ManagedObject]s are represented by this type. [ManagedSet]s properties may only be declared in the persistent
/// type of a [ManagedObject]. Example usage:
///
///        class User extends ManagedObject<_User> implements _User {}
///        class _User {
///           ...
///           ManagedSet<Post> posts;
///        }
///
///        class Post extends ManagedObject<_Post> implements _Post {}
///        class _Post {
///          ...
///          @ManagedRelationship(#posts)
///          User user;
///        }
class ManagedSet<InstanceType extends ManagedObject> extends Object
    with ListMixin<InstanceType>
    implements HTTPSerializable {
  /// Creates an empty [ManagedSet].
  ManagedSet() {
    _innerValues = [];
    entity =
        ManagedContext.defaultContext.dataModel.entityForType(InstanceType);
  }

  /// Creates a [ManagedSet] from an [Iterable] of [InstanceType]s.
  ManagedSet.from(Iterable<InstanceType> items) {
    _innerValues = items.toList();
    entity =
        ManagedContext.defaultContext.dataModel.entityForType(InstanceType);
  }

  List<InstanceType> _innerValues;
  InstanceType _whereBuider;

  /// The [ManagedEntity] that represents the [InstanceType].
  ManagedEntity entity;

  /// Whether or not [haveAtLeastOneWhere] has been accessed.
  ///
  /// This flag is used internally to determine whether or not a [Query] should
  /// be built using the values in [haveAtLeastOneWhere].
  bool get hasWhereBuilder => _whereBuider != null;

  /// When building a [Query], apply filters to a property of this type.
  ///
  /// See [Query.where] for more details. When constructing a [Query.where] that includes
  /// instances from this [ManagedSet], you may add matchers (such as [whereEqualTo]) to this property's properties to further
  /// constrain the values returned from the [Query].
  InstanceType get haveAtLeastOneWhere {
    if (_whereBuider == null) {
      _whereBuider = entity.newInstance() as InstanceType;
      _whereBuider.backing = new ManagedMatcherBacking();
    }
    return _whereBuider;
  }

  /// The number of elements in this set.
  int get length => _innerValues.length;
  void set length(int newLength) {
    _innerValues.length = newLength;
  }

  Map<String, dynamic> get backingMap => haveAtLeastOneWhere.backingMap;

  /// Adds an [InstanceType] to this set.
  void add(InstanceType item) {
    _innerValues.add(item);
  }

  /// Adds an [Iterable] of [InstanceType] to this set.
  void addAll(Iterable<InstanceType> items) {
    _innerValues.addAll(items);
  }

  /// Retrieves an [InstanceType] from this set by an index.
  InstanceType operator [](int index) => _innerValues[index];

  /// Set an [InstanceType] in this set by an index.
  operator []=(int index, InstanceType value) {
    _innerValues[index] = value;
  }

  /// Returns a serialized [List] of the elements in this set.
  dynamic asSerializable() {
    return _innerValues.map((i) => i.asSerializable()).toList();
  }
}
