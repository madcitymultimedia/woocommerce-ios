# Copiable

In the WooCommerce module, we generally work with [immutable objects](../Yosemite/Yosemite/Model/Model.swift). Mutation only happens within Yosemite and Storage. This is an intentional design and promotes clarity of [where and when those objects will be updated](https://git.io/JvALp).

But in order to _update_ something, we still need to pass an _updated_ object to Yosemite. For example, to use the [`ProductAction.updateProduct`](../Yosemite/Yosemite/Actions/ProductAction.swift) action, we'd probably have to create a new [`Product`](../Networking/Networking/Model/Product/Product.swift) object:

```swift
// An existing Product instance given by Yosemite
let currentProduct: Product

// Update the Product instance with a new `name`
let updatedProduct = Product(
    productID: currentProduct.productID,
    name: "A new name", // The only updated property
    slug: currentProduct.slug,
    permalink: currentProduct.permalink,
    dateCreated: currentProduct.dateCreated,
    dateModified: currentProduct.dateModified,
    dateOnSaleStart: currentProduct.dateOnSaleStart,

    // And so on...
)

let action = ProductAction.updateProduct(product: updatedProduct, ...)
store.dispatch(action)
```

This is quite cumbersome, especially since `Product` has more than 50 properties.

To help with this, we generate `copy()` methods for these objects. These `copy()` methods follow a specific pattern and will make use of the [`CopiableProp` and `NullableCopiableProp` typealiases](../CodeGeneration/Sources/Codegen/Copiable/Copiable.swift).

Here is an example implementation on a `Person` `struct`:

```swift
struct Person {
    let id: Int
    let name: String
    let address: String?
}

/// This will be automatically generated
extension Person {
    func copy(
        id: CopiableProp<Int> = .copy,
        name: CopiableProp<String> = .copy,
        address: NullableCopiableProp<String> = .copy
    ) -> Person {
        // Create local variables to reduce Swift compilation complexity.
        let id = id ?? self.id
        let name = name ?? self.name
        let address = address ?? self.address

        return Person(
            id: id
            name: name
            address: address
        )
    }
}
```

The `copy()` arguments match the `Person`'s properties. For the `Optional` properties like `address`, the `NullableCopiableProp` typealias is used.

By default, not passing any argument would only create a _copy_ of the `Person` instance. Passing an argument would _replace_ that property's value:

```swift
let luke = Person(id: 1, name: "Luke", address: "Jakku")

let leia = luke.copy(name: "Leia")
```

In the above, `leia` would have the same `id` and `address` as `luke` because those arguments were not given.

```swift
{ id: 1, name: "Leia", address: "Jakku" }
```

The `address` property, declared as `NullableCopiableProp<String>` has an additional functionality. Because it is `Optional`, we should be able to set its value to `nil`. We can do that by passing an `Optional` variable as the argument:

```swift
let luke = Person(id: 1, name: "Luke", address: "Jakku")

let address: String? = nil

let lukeWithNoAddress = luke.copy(address: address)
```

The `lukeWithNoAddress` variable will have a `nil` address as expected:

```swift
{ id: 1, name: "Luke", address: nil }
```

If we want to _directly_ set the `address` to `nil`, we should **not** pass just `nil`. This is because `nil` is just the same as `.copy` in this context. Instead, we should pass `.some(nil)` instead.

```swift
let luke = Person(id: 1, name: "Luke", address: "Jakku")

// DO NOT
// Result will be incorrect: { id: 1, name: "Luke", address: "Jakku" }
let lukeWithNoAddress = luke.copy(address: nil)

// DO
// Result will be { id: 1, name: "Luke", address: nil }
let lukeWithNoAddress = luke.copy(address: .some(nil))
```



## Generating Copiable Methods

The `copy()` methods are generated using [Sourcery](https://github.com/krzysztofzablocki/Sourcery). For now, only the classes or structs in the WooCommerce, Yosemite, Networking, and Storage modules are supported.

To generate a `copy()` method for a `class` or `struct`:

1. Make it conform to [`GeneratedCopiable`](../CodeGeneration/Sources/Codegen/Copiable/GeneratedCopiable.swift). 

    ```swift
    import Codegen

    struct ProductSettings: GeneratedCopiable {
        ...
    }
    ```

2. In terminal, navigate to the project's root folder and run `rake generate`.

    ```
    $ cd /path/to/root
    $ rake generate
    ```

    This will generate separate files for every module. For example:

    ```
    WooCommerce/Classes/Copiable/Models+Copiable.generated.swift
    Yosemite/Yosemite/Model/Copiable/Models+Copiable.generated.swift
    ```

3. Add the generated files to the appropriate project if they're not added yet.
4. Compile the project.

## Modifying The Copiable Code Generation

The [`rake generate`](../Rakefile) command executes the Sourcery configuration files located in the [`CodeGeneration` folder](../CodeGeneration/Sourcery/Copiable). There are different configuration files for every module:

```
Hardware module → Hardware-Copiable.sourcery.yaml
Networking module → Networking-Copiable.sourcery.yaml
Storage module → Storage-Copiable.sourcery.yaml
WooCommerce module → WooCommerce-Copiable.sourcery.yaml
Yosemite module → Yosemite-Copiable.sourcery.yaml
```

All of them use a single template, [`Models+Copiable.swifttemplate`](../CodeGeneration/Sourcery/Copiable/Models+Copiable.swifttemplate), to generate the code. It's written using [Swift templates](https://cdn.rawgit.com/krzysztofzablocki/Sourcery/master/docs/writing-templates.html).

Please refer to the [Sourcery reference](https://cdn.rawgit.com/krzysztofzablocki/Sourcery/master/docs/index.html) for more info about how to write templates.

## Adding Copiable to a New Xcode Framework

1. In Xcode target settings, add Codegen to the Xcode framework in General > Frameworks and Libraries.  
2. Add a new file `{{FrameworkName}}-Copiable.sourcery.yaml` under [`CodeGeneration/Sourcery/Copiable`](../CodeGeneration/Sourcery/Copiable) similar to other yaml files in the same folder.
3. In [`Rakefile`](../Rakefile) which includes the script for `rake generate` command, add the new framework to the list of frameworks for Copiable generation similar to other frameworks.
4. In the new Xcode framework, add a new folder `Model/Copiable` in the file hierarchy. 
5. Now you can try generating copy methods as instructed in an earlier section.
6. In the new Xcode framework, add the newly generated file `Models+Copiable.generated.swift` under the new folder `Model/Copiable`. 
