import 'package:test/test.dart';
import 'package:aqueduct/aqueduct.dart';
import '../model_graph.dart';
import '../../helpers.dart';

/*
  The more rigid tests on joining are covered by tiered_where, has_many and has_one tests.
  These just check to ensure that belongsTo joins are going to net out the same.
 */

void main() {
  justLogEverything();
  List<RootObject> rootObjects;
  ManagedContext ctx;
  setUpAll(() async {
    ctx = await contextWithModels([
      RootObject,
      RootJoinObject,
      OtherRootObject,
      ChildObject,
      GrandChildObject
    ]);
    rootObjects = await populateModelGraph(ctx);
  });

  tearDownAll(() async {
    await ctx.persistentStore.close();
  });

  // Matching on a belongsTo property for a foreign key doesn't need join, but anything else does

  group("Assign non-join matchers to belongsToProperty", () {
    test("Can use whereRelatedByValue", () async {
      var q = new Query<ChildObject>()
          ..where.parents = whereRelatedByValue(1);
      var results = await q.fetch();

      expect(results.length, rootObjects.firstWhere((r) => r.id == 1).children.length);
      for (var child in rootObjects.first.children) {
        var matching = results.firstWhere((c) => c.id == child.id);
        expect(child.value1, matching.value1);
        expect(child.value2, matching.value2);
        expect(child.parents.id, 1);
      }
    });

    test("Can match on belongsTo relationship's primary key, does not cause join", () async {
      var q = new Query<ChildObject>()
        ..where.parents.id = whereEqualTo(1);
      var results = await q.fetch();

      expect(results.length, rootObjects.firstWhere((r) => r.id == 1).children.length);
      for (var child in rootObjects.first.children) {
        var matching = results.firstWhere((c) => c.id == child.id);
        expect(child.value1, matching.value1);
        expect(child.value2, matching.value2);
        expect(child.parents.id, 1);
      }
    });

    test("Can use whereNull", () async {
      var q = new Query<ChildObject>()
        ..where.parents = whereNull;
      var results = await q.fetch();

      var childNotChildren = rootObjects
          .expand((r) => [r.child])
          .where((c) => c != null)
          .toList();

      expect(results.length, childNotChildren.length);
      childNotChildren.forEach((c) {
        expect(results.firstWhere((resultChild) => c.id == resultChild.id), isNotNull);
      });

      q = new Query<ChildObject>()
        ..where.parent = whereNull;
      results = await q.fetch();

      var childrenNotChild = rootObjects
          .expand((r) => r.children ?? [])
          .toList();

      expect(results.length, childrenNotChild.length);
      childrenNotChild.forEach((c) {
        expect(results.firstWhere((resultChild) => c.id == resultChild.id), isNotNull);
      });
    });

    test("Can use whereNotNull", () async {
      var q = new Query<ChildObject>()
        ..where.parents = whereNull;
      var results = await q.fetch();

      var childNotChildren = rootObjects
          .expand((r) => [r.child])
          .where((c) => c != null)
          .toList();

      expect(results.length, childNotChildren.length);
      childNotChildren.forEach((c) {
        expect(results.firstWhere((resultChild) => c.id == resultChild.id), isNotNull);
      });

      q = new Query<ChildObject>()
        ..where.parent = whereNull;
      results = await q.fetch();
      var childrenNotChild = rootObjects
          .expand((r) => r.children ?? [])
          .toList();

      expect(results.length, childrenNotChild.length);
      childrenNotChild.forEach((c) {
        expect(results.firstWhere((resultChild) => c.id == resultChild.id), isNotNull);
      });
    });
  });

  group("Join on parent of hasMany relationship", () {
    test("Standard join", () async {
      var q = new Query<ChildObject>()
          ..joinOn((c) => c.parents);
      var results = await q.fetch();

      expect(results.map((c) => c.asMap()).toList(), equals([
        fullObjectMap(1, and: {"parents": null, "parent": {"id" : 1}}),
        fullObjectMap(2, and: {"parents": fullObjectMap(1), "parent": null}),
        fullObjectMap(3, and: {"parents": fullObjectMap(1), "parent": null}),
        fullObjectMap(4, and: {"parents": fullObjectMap(1), "parent": null}),
        fullObjectMap(5, and: {"parents": fullObjectMap(1), "parent": null}),
        fullObjectMap(6, and: {"parents": null, "parent": {"id": 2}}),
        fullObjectMap(7, and: {"parents": fullObjectMap(2), "parent": null}),
        fullObjectMap(8, and: {"parents": null, "parent": {"id": 3}}),
        fullObjectMap(9, and: {"parents": fullObjectMap(4), "parent": null})
      ]));
    });

    test("Nested join", () async {
      var q = new Query<GrandChildObject>();
      q.joinOn((c) => c.parents)
        ..joinOn((c) => c.parents);
      var results = await q.fetch();

      expect(results.map((g) => g.asMap()).toList(), equals([
        fullObjectMap(1, and: {"parents": null, "parent": {"id": 1}}),
        fullObjectMap(2, and: {"parent": null,
          "parents": fullObjectMap(1, and: {"parents": null, "parent": {"id": 1}})}),
        fullObjectMap(3, and: {"parent": null,
          "parents": fullObjectMap(1, and: {"parents": null, "parent": {"id": 1}})}),
        fullObjectMap(4, and: {"parents": null, "parent": {"id": 2}}),
        fullObjectMap(5, and: {"parent": null,
          "parents": fullObjectMap(2, and: {"parents": fullObjectMap(1), "parent": null})}),
        fullObjectMap(6, and: {"parent": null,
          "parents": fullObjectMap(2, and: {"parents": fullObjectMap(1), "parent": null})}),
        fullObjectMap(7, and: {"parents": null, "parent": {"id": 3}}),
        fullObjectMap(8, and: {"parent": null,
          "parents": fullObjectMap(4, and: {"parents": fullObjectMap(1), "parent": null})}),
      ]));
    });

    // nested, double nested

  });

  group("Join on parent of hasOne relationship", () {
    // nested, double nested
  });

  group("Fetch parent and grandchild from child", () {

  });

  group("Implicit joins", () {

  });


}
