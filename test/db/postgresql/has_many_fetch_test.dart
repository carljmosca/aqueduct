import 'package:test/test.dart';
import 'package:aqueduct/aqueduct.dart';
import 'dart:async';
import '../../helpers.dart';

/*
  The test data is like so:

           A       B       C      D
         /   \     | \     |
        C1    C2  C3  C4  C5
      / | \    |   |
    T1 V1 V2  T2  V3
 */

void main() {
  group("Happy path", () {
    ManagedContext context = null;
    List<Parent> truth;
    setUpAll(() async {
      context = await contextWithModels([Child, Parent, Toy, Vaccine]);
      truth = await populate();
    });

    tearDownAll(() async {
      await context?.persistentStore?.close();
    });

    test("Fetch has-many relationship that has none returns empty OrderedSet",
        () async {
      var q = new Query<Parent>()
        ..joinMany((p) => p.children)
        ..where.name = "D";

      var verifier = (Parent p) {
        expect(p.name, "D");
        expect(p.pid, isNotNull);
        expect(p.children, []);
      };
      verifier(await q.fetchOne());
      verifier((await q.fetch()).first);
    });

    test(
        "Fetch has-many relationship that is empty returns empty, and deeper nested relationships are ignored even when included",
        () async {
      var q = new Query<Parent>()..where.name = "D";

      q.joinMany((p) => p.children)
        ..joinOne((c) => c.toy)
        ..joinMany((c) => c.vaccinations);

      var verifier = (Parent p) {
        expect(p.name, "D");
        expect(p.pid, isNotNull);
        expect(p.children, []);
      };
      verifier(await q.fetchOne());
      verifier((await q.fetch()).first);
    });

    test(
        "Fetch has-many relationship that is non-empty returns values for scalar properties in subobjects only",
        () async {
      var q = new Query<Parent>()
        ..joinMany((p) => p.children)
        ..where.name = "C";

      var verifier = (Parent p) {
        expect(p.name, "C");
        expect(p.pid, isNotNull);
        expect(p.children.first.cid, isNotNull);
        expect(p.children.first.name, "C5");
        expect(p.children.first.backingMap.containsKey("toy"), false);
        expect(p.children.first.backingMap.containsKey("vaccinations"), false);
      };
      verifier(await q.fetchOne());
      verifier((await q.fetch()).first);
    });

    test(
        "Fetch has-many relationship, include has-one and has-many in that has-many, where bottom of graph has valid object for hasmany but not for hasone",
        () async {
      var q = new Query<Parent>()..where.name = "B";

      q.joinMany((p) => p.children)
        ..sortBy((c) => c.cid, QuerySortOrder.ascending)
        ..joinOne((c) => c.toy)
        ..joinMany((c) => c.vaccinations);

      var verifier = (Parent p) {
        expect(p.name, "B");
        expect(p.pid, isNotNull);
        expect(p.children.first.cid, isNotNull);
        expect(p.children.first.name, "C3");
        expect(p.children.first.backingMap.containsKey("toy"), true);
        expect(p.children.first.toy, isNull);
        expect(p.children.first.vaccinations.length, 1);
        expect(p.children.first.vaccinations.first.vid, isNotNull);
        expect(p.children.first.vaccinations.first.kind, "V3");

        expect(p.children.last.cid, isNotNull);
        expect(p.children.last.name, "C4");
        expect(p.children.last.backingMap.containsKey("toy"), true);
        expect(p.children.last.toy, isNull);
        expect(p.children.last.vaccinations, []);
      };

      verifier(await q.fetchOne());
      verifier((await q.fetch()).first);
    });

    test(
        "Fetch has-many relationship, include has-one and has-many in that has-many, where bottom of graph has valid object for hasone but not for hasmany",
        () async {
      var q = new Query<Parent>()..where.name = "A";

      q.joinMany((p) => p.children)
        ..sortBy((c) => c.cid, QuerySortOrder.ascending)
        ..joinOne((c) => c.toy)
        ..joinMany((c) => c.vaccinations)
            .sortBy((v) => v.vid, QuerySortOrder.ascending);

      var verifier = (Parent p) {
        expect(p.name, "A");
        expect(p.pid, isNotNull);
        expect(p.children.first.cid, isNotNull);
        expect(p.children.first.name, "C1");
        expect(p.children.first.toy.tid, isNotNull);
        expect(p.children.first.toy.name, "T1");
        expect(p.children.first.vaccinations.length, 2);
        expect(p.children.first.vaccinations.first.vid, isNotNull);
        expect(p.children.first.vaccinations.first.kind, "V1");
        expect(p.children.first.vaccinations.last.vid, isNotNull);
        expect(p.children.first.vaccinations.last.kind, "V2");

        expect(p.children.last.cid, isNotNull);
        expect(p.children.last.name, "C2");
        expect(p.children.last.toy.tid, isNotNull);
        expect(p.children.last.toy.name, "T2");
        expect(p.children.last.vaccinations, []);
      };

      verifier(await q.fetchOne());
      verifier((await q.fetch()).first);
    });

    test(
        "Fetching multiple top-level instances and including one level of subobjects",
        () async {
      var q = new Query<Parent>()
        ..sortBy((p) => p.pid, QuerySortOrder.ascending)
        ..joinMany((p) => p.children)
        ..where.name = whereIn(["A", "C", "D"]);
      var results = await q.fetch();
      expect(results.length, 3);

      expect(results.first.pid, isNotNull);
      expect(results.first.name, "A");
      expect(results.first.children.length, 2);
      expect(results.first.children.first.name, "C1");
      expect(results.first.children.first.backingMap.containsKey("toy"), false);
      expect(
          results.first.children.first.backingMap.containsKey("vaccinations"),
          false);
      expect(results.first.children.last.name, "C2");
      expect(results.first.children.last.backingMap.containsKey("toy"), false);
      expect(results.first.children.last.backingMap.containsKey("vaccinations"),
          false);

      expect(results[1].pid, isNotNull);
      expect(results[1].name, "C");
      expect(results[1].children.length, 1);
      expect(results[1].children.first.name, "C5");
      expect(results[1].children.first.backingMap.containsKey("toy"), false);
      expect(results[1].children.first.backingMap.containsKey("vaccinations"),
          false);

      expect(results.last.pid, isNotNull);
      expect(results.last.name, "D");
      expect(results.last.children.length, 0);
    });

    test("Fetch entire graph", () async {
      var q = new Query<Parent>();
      q.joinMany((p) => p.children)
        ..joinOne((c) => c.toy)
        ..joinMany((c) => c.vaccinations);

      var all = await q.fetch();

      var originalIterator = truth.iterator;
      for (var p in all) {
        originalIterator.moveNext();
        expect(p.pid, originalIterator.current.pid);
        expect(p.name, originalIterator.current.name);

        var originalChildrenIterator = p.children.iterator;
        p.children?.forEach((child) {
          originalChildrenIterator.moveNext();
          expect(child.cid, originalChildrenIterator.current.cid);
          expect(child.name, originalChildrenIterator.current.name);
          expect(child.toy?.tid, originalChildrenIterator.current.toy?.tid);
          expect(child.toy?.name, originalChildrenIterator.current.toy?.name);

          var vacIter =
              originalChildrenIterator.current.vaccinations?.iterator ??
                  <Vaccine>[].iterator;
          child.vaccinations?.forEach((v) {
            vacIter.moveNext();
            expect(v.vid, vacIter.current.vid);
            expect(v.kind, vacIter.current.kind);
          });
          expect(vacIter.moveNext(), false);
        });
      }
      expect(originalIterator.moveNext(), false);
    });
  });

  ////

  group("Happy path with predicates", () {
    ManagedContext context = null;

    setUpAll(() async {
      context = await contextWithModels([Child, Parent, Toy, Vaccine]);
      await populate();
    });

    tearDownAll(() {
      context?.persistentStore?.close();
    });

    test("Predicate impacts top-level objects when fetching object graph",
        () async {
      var q = new Query<Parent>()..where.name = "A";

      q.joinMany((p) => p.children)
        ..sortBy((c) => c.cid, QuerySortOrder.ascending)
        ..joinOne((c) => c.toy)
        ..joinMany((c) => c.vaccinations)
            .sortBy((v) => v.vid, QuerySortOrder.ascending);

      var results = await q.fetch();

      expect(results.length, 1);

      var p = results.first;

      expect(p.name, "A");
      expect(p.children.first.name, "C1");
      expect(p.children.first.toy.name, "T1");
      expect(p.children.first.vaccinations.first.kind, "V1");
      expect(p.children.first.vaccinations.last.kind, "V2");
      expect(p.children.last.name, "C2");
      expect(p.children.last.toy.name, "T2");
      expect(p.children.last.vaccinations, []);
    });

    test("Predicate impacts 2nd level objects when fetching object graph",
        () async {
      var q = new Query<Parent>();

      q.joinMany((p) => p.children)
        ..where.name = "C1"
        ..sortBy((c) => c.cid, QuerySortOrder.ascending)
        ..joinMany((c) => c.vaccinations)
            .sortBy((v) => v.vid, QuerySortOrder.ascending)
        ..joinOne((c) => c.toy);

      var results = await q.fetch();

      expect(results.length, 4);

      for (var p in results.sublist(1)) {
        expect(p.children, []);
      }

      var p = results.first;
      expect(p.children.length, 1);
      expect(p.children.first.name, "C1");
      expect(p.children.first.toy.name, "T1");
      expect(p.children.first.vaccinations.first.kind, "V1");
      expect(p.children.first.vaccinations.last.kind, "V2");
    });

    test("Predicate impacts 3rd level objects when fetching object graph",
        () async {
      var q = new Query<Parent>();

      var childJoin = q.joinMany((p) => p.children)..joinOne((c) => c.toy);
      childJoin.joinMany((c) => c.vaccinations)..where.kind = "V1";

      var results = await q.fetch();

      expect(results.length, 4);

      expect(results.first.name, "A");
      expect(results.first.children.first.name, "C1");
      expect(results.first.children.first.toy.name, "T1");
      expect(results.first.children.first.vaccinations.length, 1);
      expect(results.first.children.first.vaccinations.first.kind, "V1");
      expect(results.first.children.last.name, "C2");
      expect(results.first.children.last.toy.name, "T2");
      expect(results.first.children.last.vaccinations.length, 0);

      expect(results[1].name, "B");
      expect(results[1].children.first.name, "C3");
      expect(results[1].children.first.toy, isNull);
      expect(results[1].children.first.vaccinations.length, 0);
      expect(results[1].children.last.name, "C4");
      expect(results[1].children.last.toy, isNull);
      expect(results[1].children.last.vaccinations.length, 0);

      expect(results[2].name, "C");
      expect(results[2].children.first.name, "C5");
      expect(results[2].children.first.toy, isNull);
      expect(results[2].children.first.vaccinations.length, 0);

      expect(results[3].name, "D");
      expect(results[3].children, []);
    });

    test(
        "Predicate that omits top-level objects but would include lower level object return no results",
        () async {
      var q = new Query<Parent>()..where.pid = 5;

      var childJoin = q.joinMany((p) => p.children)..joinOne((c) => c.toy);
      childJoin.joinMany((c) => c.vaccinations)..where.kind = "V1";

      var results = await q.fetch();
      expect(results.length, 0);
    });
  });

  group("Sort descriptor impact", () {
    ManagedContext context = null;
    List<Parent> truth;

    setUpAll(() async {
      context = await contextWithModels([Child, Parent, Toy, Vaccine]);
      truth = await populate();
    });

    tearDownAll(() {
      context?.persistentStore?.close();
    });

    test(
        "Sort descriptor on top-level object doesn't impact lower level objects",
        () async {
      var q = new Query<Parent>()
        ..sortBy((p) => p.name, QuerySortOrder.descending);

      q.joinMany((p) => p.children)
        ..joinOne((c) => c.toy)
        ..joinMany((c) => c.vaccinations);

      var results = await q.fetch();

      var originalIterator = truth.reversed.iterator;
      for (var p in results) {
        originalIterator.moveNext();
        expect(p.pid, originalIterator.current.pid);
        expect(p.name, originalIterator.current.name);

        var originalChildrenIterator = p.children.iterator;
        p.children?.forEach((child) {
          originalChildrenIterator.moveNext();
          expect(child.cid, originalChildrenIterator.current.cid);
          expect(child.name, originalChildrenIterator.current.name);
          expect(child.toy?.tid, originalChildrenIterator.current.toy?.tid);
          expect(child.toy?.name, originalChildrenIterator.current.toy?.name);

          var vacIter =
              originalChildrenIterator.current.vaccinations?.iterator ??
                  <Vaccine>[].iterator;
          child.vaccinations?.forEach((v) {
            vacIter.moveNext();
            expect(v.vid, vacIter.current.vid);
            expect(v.kind, vacIter.current.kind);
          });
          expect(vacIter.moveNext(), false);
        });
      }
      expect(originalIterator.moveNext(), false);
    });
  });

  group("Offhand assumptions about data", () {
    ManagedContext context = null;

    setUpAll(() async {
      context = await contextWithModels([Child, Parent, Toy, Vaccine]);
      await populate();
    });

    tearDownAll(() {
      context?.persistentStore?.close();
    });

    test("Objects returned in join are not the same instance", () async {
      var q = new Query<Parent>()
        ..where.pid = 1
        ..joinMany((p) => p.children);

      var o = await q.fetchOne();
      for (var c in o.children) {
        expect(identical(c.parent, o), false);
      }
    });
  });

  group("Bad usage cases", () {
    ManagedContext context = null;

    setUpAll(() async {
      context = await contextWithModels([Child, Parent, Toy, Vaccine]);
      await populate();
    });

    tearDownAll(() {
      context?.persistentStore?.close();
    });

    test("Trying to fetch hasMany relationship through resultProperties fails",
        () async {
      var q = new Query<Parent>()
        ..returningProperties((p) => [p.pid, p.children]);
      try {
        await q.fetchOne();
      } on QueryException catch (e) {
        expect(
            e.toString(),
            contains(
                "Property 'children' is a hasMany or hasOne relationship and is invalid as a result property of '_Parent'"));
      }
    });

    test("Trying to fetch hasMany relationship through resultProperties fails",
        () async {
      var q = new Query<Parent>()
        ..returningProperties((p) => [p.pid, p.children]);
      try {
        await q.fetchOne();
        expect(true, false);
      } on QueryException catch (e) {
        expect(
            e.toString(),
            contains(
                "Property 'children' is a hasMany or hasOne relationship and is invalid as a result property of '_Parent'"));
      }

      q = new Query<Parent>();
      q.joinMany((p) => p.children)
        ..returningProperties((p) => [p.cid, p.vaccinations]);

      try {
        await q.fetchOne();
        expect(true, false);
      } on QueryException catch (e) {
        expect(
            e.toString(),
            contains(
                "Property 'vaccinations' is a hasMany or hasOne relationship and is invalid as a result property of '_Child'"));
      }
    });
  });
}

class Parent extends ManagedObject<_Parent> implements _Parent {}

class _Parent {
  @managedPrimaryKey
  int pid;
  String name;

  ManagedSet<Child> children;
}

class Child extends ManagedObject<_Child> implements _Child {}

class _Child {
  @managedPrimaryKey
  int cid;
  String name;

  @ManagedRelationship(#children)
  Parent parent;

  Toy toy;

  ManagedSet<Vaccine> vaccinations;
}

class Toy extends ManagedObject<_Toy> implements _Toy {}

class _Toy {
  @managedPrimaryKey
  int tid;

  String name;

  @ManagedRelationship(#toy)
  Child child;
}

class Vaccine extends ManagedObject<_Vaccine> implements _Vaccine {}

class _Vaccine {
  @managedPrimaryKey
  int vid;
  String kind;

  @ManagedRelationship(#vaccinations)
  Child child;
}

Future<List<Parent>> populate() async {
  var modelGraph = <Parent>[];
  var parents = [
    new Parent()
      ..name = "A"
      ..children = new ManagedSet<Child>.from([
        new Child()
          ..name = "C1"
          ..toy = (new Toy()..name = "T1")
          ..vaccinations = (new ManagedSet<Vaccine>.from([
            new Vaccine()..kind = "V1",
            new Vaccine()..kind = "V2",
          ])),
        new Child()
          ..name = "C2"
          ..toy = (new Toy()..name = "T2")
      ]),
    new Parent()
      ..name = "B"
      ..children = new ManagedSet<Child>.from([
        new Child()
          ..name = "C3"
          ..vaccinations =
              (new ManagedSet<Vaccine>.from([new Vaccine()..kind = "V3"])),
        new Child()..name = "C4"
      ]),
    new Parent()
      ..name = "C"
      ..children = new ManagedSet<Child>.from([new Child()..name = "C5"]),
    new Parent()..name = "D"
  ];

  for (var p in parents) {
    var q = new Query<Parent>()..values.name = p.name;
    var insertedParent = await q.insert();
    modelGraph.add(insertedParent);

    insertedParent.children = new ManagedSet<Child>();
    for (var child in p.children ?? <Child>[]) {
      var childQ = new Query<Child>()
        ..values.name = child.name
        ..values.parent = insertedParent;
      insertedParent.children.add(await childQ.insert());

      if (child.toy != null) {
        var toyQ = new Query<Toy>()
          ..values.name = child.toy.name
          ..values.child = insertedParent.children.last;
        insertedParent.children.last.toy = await toyQ.insert();
      }

      if (child.vaccinations != null) {
        insertedParent.children.last.vaccinations =
            new ManagedSet<Vaccine>.from(
                await Future.wait(child.vaccinations.map((v) {
          var vQ = new Query<Vaccine>()
            ..values.kind = v.kind
            ..values.child = insertedParent.children.last;
          return vQ.insert();
        })));
      }
    }
  }

  return modelGraph;
}
