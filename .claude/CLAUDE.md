## instructions

### code quality

- follow clean code principles
- try not to nest statements past 3 layers when possible
- code should be self desribing, variables should have a clear name that explains exactly what they are there for, functions as well
- write self descriptive code rather than comments, if the code doescribe itself easily and needs comments, its probably not good code
- no code comments except for expceptionally complex code structure with multiple code paths
- always declare return types for function
- a function should where possible only "do one thing", try not to write functions/methods with multiple purposes

good:

```dart
class Pet {
    final String name;
      Pet({
    required this.name,
  });

   void printName() {
    print(name)
    }

  }

```

bad:

```dart
//A class Model for pets
class Pet {
    final String name;
      Pet({
    required this.name,
  });
    //prints the name of the pet
   void printName() {
    print(name)
    }

  }

```
