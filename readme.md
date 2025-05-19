# TP : Conception d'Index Elasticsearch à partir de Données Relationnelles avec Node.js

## Objectifs pédagogiques

À la fin de ce TP, vous serez capable de :
- Analyser un modèle de données relationnel et identifier les opportunités de dénormalisation.
- Concevoir un mapping Elasticsearch optimisé pour la recherche.
- Transformer des données relationnelles en documents JSON pour Elasticsearch.
- Indexer efficacement les données dans Elasticsearch avec Node.js.
- Tester et valider la pertinence de votre conception à travers des requêtes.

## Durée

**4 heures**

## Prérequis

- Elasticsearch 7.x ou 8.x installé et fonctionnel.
- MySQL/MariaDB ou PostgreSQL installé.
- Node.js (version 14+) et npm installés.
- Connaissances de base en SQL et JSON.
- Postman, curl ou Kibana Dev Tools pour tester les requêtes.

## Jeu de données

Pour ce TP, nous utiliserons le jeu de données **Northwind**, une base de données relationnelle classique représentant un système de gestion de commandes pour une entreprise fictive.

### Sources pour obtenir le jeu de données Northwind :
- [GitHub - pthom/northwind_psql](https://github.com/pthom/northwind_psql) - Version PostgreSQL.
- [GitHub - dalers/mywind](https://github.com/dalers/mywind) - Version MySQL.
- [SQL Server Samples - Northwind-pubs](https://github.com/microsoft/sql-server-samples) - Version SQL Server (adaptable).

Choisissez la version qui correspond à votre SGBD et suivez les instructions du repository pour l'importation.

### Structure de la base de données Northwind

La base de données Northwind contient plusieurs tables interconnectées :
- **customers** : Informations sur les clients.
- **employees** : Détails des employés.
- **orders** : Commandes passées par les clients.
- **order_details** : Lignes de commande détaillant les produits commandés.
- **products** : Catalogue de produits.
- **categories** : Catégories de produits.
- **suppliers** : Fournisseurs des produits.
- **shippers** : Transporteurs pour les livraisons.

---

## Plan du TP

### Partie 1 : Analyse du modèle relationnel (45 min)
1. **Explorer la structure de la base de données Northwind** :
    - Exécutez des requêtes pour comprendre la structure des tables principales.
    - Identifiez les clés primaires et étrangères.

   **Réponses**
##### Requêtes exécutées

```sql
-- Liste des produits avec leurs catégories et fournisseurs
SELECT p.ProductID, p.ProductName, c.CategoryName, s.CompanyName AS SupplierName
FROM Products p
JOIN Categories c ON p.CategoryID = c.CategoryID
JOIN Suppliers s ON p.SupplierID = s.SupplierID;

-- Liste des commandes avec client et employé
SELECT o.OrderID, o.OrderDate, c.CompanyName, e.FirstName, e.LastName
FROM Orders o
JOIN Customers c ON o.CustomerID = c.CustomerID
JOIN Employees e ON o.EmployeeID = e.EmployeeID;

-- Détail d'une commande (exemple avec OrderID 10248)
SELECT od.OrderID, p.ProductName, od.UnitPrice, od.Quantity, od.Discount
FROM [Order Details] od
JOIN Products p ON od.ProductID = p.ProductID
WHERE od.OrderID = 10248;

```

##### Clés primaires (PK) et étrangères (FK)

###### Tables et clés primaires

| Table          | Clé primaire         |
|----------------|----------------------|
| Products       | ProductID            |
| Categories     | CategoryID           |
| Suppliers      | SupplierID           |
| Customers      | CustomerID           |
| Employees      | EmployeeID           |
| Shippers       | ShipperID            |
| Orders         | OrderID              |
| Order Details  | (OrderID, ProductID) |

---

###### Tables et clés primaires

| Table         | Champ FK     | Référence                    |
|---------------|--------------|------------------------------|
| Products      | SupplierID   | Suppliers.SupplierID         |
|               | CategoryID   | Categories.CategoryID        |
| Orders        | CustomerID   | Customers.CustomerID         |
|               | EmployeeID   | Employees.EmployeeID         |
|               | ShipVia      | Shippers.ShipperID           |
| Order Details | OrderID      | Orders.OrderID               |
|               | ProductID    | Products.ProductID           |

2. **Analyser les relations entre les tables** :
    - Examinez les jointures entre les tables.
    - Identifiez les relations one-to-many et many-to-many.

   **Réponses**
##### Relations One-to-Many (1→N)

Ces relations signifient qu’un enregistrement dans la table source peut être relié à plusieurs enregistrements dans la table cible.

| Table source (1) | Table cible (many)     | Clé étrangère                        | Signification |
|------------------|------------------------|--------------------------------------|---------------|
| `categories`     | `products`             | `products.category_id`               | Une catégorie contient plusieurs produits |
| `suppliers`      | `products`             | `products.supplier_id`               | Un fournisseur fournit plusieurs produits |
| `products`       | `order_details`        | `order_details.product_id`           | Un produit peut apparaître dans plusieurs commandes |
| `orders`         | `order_details`        | `order_details.order_id`             | Une commande contient plusieurs lignes produits |
| `customers`      | `orders`               | `orders.customer_id`                 | Un client passe plusieurs commandes |
| `employees`      | `orders`               | `orders.employee_id`                 | Un employé peut traiter plusieurs commandes |
| `shippers`       | `orders`               | `orders.ship_via`                    | Un transporteur peut livrer plusieurs commandes |
| `region`         | `territories`          | `territories.region_id`              | Une région contient plusieurs territoires |
| `territories`    | `employee_territories` | `employee_territories.territory_id`  | Un territoire peut concerner plusieurs employés |
| `employees`      | `employee_territories` | `employee_territories.employee_id`   | Un employé peut être rattaché à plusieurs territoires |

---

##### Relations Many-to-Many (N→N)

Ces relations utilisent une table intermédiaire pour gérer les connexions multiples dans les deux sens.

| Tables concernées              | Table de liaison           | Détails |
|--------------------------------|-----------------------------|---------|
| `employees` ↔ `territories`    | `employee_territories`     | Un employé peut couvrir plusieurs territoires et un territoire peut avoir plusieurs employés |
| `customers` ↔ `customer_demographics` | `customer_customer_demo` | Un client peut avoir plusieurs types, et un type peut concerner plusieurs clients |
| `products` ↔ `orders`          | `order_details`             | Un produit peut apparaître dans plusieurs commandes, et une commande peut contenir plusieurs produits |
 
3. **Analyser les cas d'usage typiques pour la recherche** :
    - Réfléchissez aux types de recherches utiles dans un contexte e-commerce.
    - Identifiez les champs de recherche les plus pertinents.

   **Réponses**
##### Cas d’usage pour `products` ou `orders`

| Cas d’usage/Type de recherche                  | Description |
|------------------------------------------------|-------------|
| Recherche par nom de produit                   | Recherche full-text avec ou sans fautes de frappe |
| Filtrage par catégorie                         | Afficher uniquement les produits d’une catégorie spécifique |
| Filtrage par fournisseur                       | Par exemple, voir tous les produits fournis par "Exotic Liquids" |
| Tri par prix                                   | Tri croissant ou décroissant pour comparer les prix |
| Recherche par plage de prix                    | Trouver les produits entre 10€ et 30€ |
| Autocomplétion de noms de produits             | Suggestions pendant que l'utilisateur tape |
|                                                |                                                                  |
| Recherche de commandes par nom de client       | Ex: “Commandes de Dupont” |
| Recherche de commandes passées dans une période| Ex: “Commandes de mars 2024” |
| Affichage des produits commandés               | Pour analyser ce qui a été vendu |
| Statistiques sur les ventes                    | Total par client, produit ou période |
| Filtrage par employé ou transporteur           | Voir qui a traité/livré une commande |

##### Champs les plus pertinents à indexer et analyser** :
- `name` (analyser avec un analyzer pour le full-text)
- `category.name` (filtrable et agrégable)
- `supplier.name` (filtrable)
- `price` (filtrable et triable)

- `customer.company_name` (recherche)
- `order_date` (filtrage par date)
- `order_details.product.name` (affichage + filtre produit commandé)
- `employee` (facultatif, pour filtres avancés)

4. **Définir les objectifs pour l'index Elasticsearch** :
    - Nous créerons deux index principaux : `products` et `orders`.
    - Déterminez les informations importantes à stocker dans chaque index.

   **Réponses**
##### Index principaux

Structure proposée d’un document product :
{
  "product_id": 1,
  "product_name": "Chai",
  "quantity_per_unit": "10 boxes x 20 bags",
  "unit_price": 18.0,
  "units_in_stock": 39,
  "category": {
    "category_id": 1,
    "category_name": "Beverages",
    "description": "Soft drinks, coffees, teas"
  },
  "supplier": {
    "supplier_id": 1,
    "company_name": "Exotic Liquids",
    "contact_name": "Charlotte Cooper",
    "country": "UK"
  }
}

Structure proposée d’un document order :
{
  "order_id": 10248,
  "order_date": "1996-07-04",
  "required_date": "1996-08-01",
  "shipped_date": "1996-07-16",
  "freight": 32.38,
  "ship_name": "Vins et alcools Chevalier",
  "ship_country": "France",
  "customer": {
    "customer_id": "VINET",
    "company_name": "Vins et alcools Chevalier",
    "contact_name": "Paul Henriot",
    "country": "France"
  },
  "employee": {
    "employee_id": 5,
    "first_name": "Steven",
    "last_name": "Buchanan"
  },
  "order_details": [
    {
      "product_id": 11,
      "product_name": "Queso Cabrales",
      "quantity": 12,
      "unit_price": 14.0,
      "discount": 0.0
    },
    {
      "product_id": 42,
      "product_name": "Singaporean Hokkien Fried Mee",
      "quantity": 10,
      "unit_price": 9.8,
      "discount": 0.0
    }
  ]
}

##### Champs importants

product :

product_name : pour recherche full-text.

category.category_name : pour filtrer/agréger.

supplier.company_name : pour filtrer.

unit_price : pour filtres et tris.

units_in_stock : pour des alertes sur le stock (optionnel).

order :

order_date, shipped_date : pour les recherches par période.

customer.company_name, customer.country : pour recherche et filtrage.

order_details.product_name : utile pour voir les produits commandés.

freight : pour analyse logistique ou coût.

employee et shipper : pour des filtres avancés ou statistiques.

### Partie 2 : Conception du mapping Elasticsearch (60 min)
1. **Déterminer quelles tables doivent être dénormalisées** :
    - Analysez les relations et décidez quelles données fusionner.
    - Identifiez les données à embarquer dans les documents (par exemple : catégories dans produits).
    
   **Réponses**
##### Structure des documents

{
  "product_id": 1,
  "product_name": "Chai",
  "quantity_per_unit": "10 boxes x 20 bags",
  "unit_price": 18.0,
  "units_in_stock": 39,
  "discontinued": false,
  "category": {
    "category_id": 1,
    "category_name": "Beverages",
    "description": "Soft drinks, coffees, teas"
  },
  "supplier": {
    "supplier_id": 1,
    "company_name": "Exotic Liquids",
    "contact_name": "Charlotte Cooper",
    "country": "UK"
  }
}

{
  "order_id": 10248,
  "order_date": "1996-07-04",
  "required_date": "1996-08-01",
  "shipped_date": "1996-07-16",
  "freight": 32.38,
  "ship_name": "Vins et alcools Chevalier",
  "ship_country": "France",
  "customer": {
    "customer_id": "VINET",
    "company_name": "Vins et alcools Chevalier",
    "contact_name": "Paul Henriot",
    "country": "France"
  },
  "employee": {
    "employee_id": 5,
    "first_name": "Steven",
    "last_name": "Buchanan"
  },
  "shipper": {
    "shipper_id": 3,
    "company_name": "Federal Shipping"
  },
  "order_details": [
    {
      "product_id": 11,
      "product_name": "Queso Cabrales",
      "quantity": 12,
      "unit_price": 14.0,
      "discount": 0.0
    },
    {
      "product_id": 42,
      "product_name": "Singaporean Hokkien Fried Mee",
      "quantity": 10,
      "unit_price": 9.8,
      "discount": 0.0
    }
  ]
}

2. **Concevoir la structure des documents** :
    - **Produits** : inclure les informations des catégories et fournisseurs.
    - **Commandes** : inclure les informations clients et les détails des produits commandés.
        
   **Réponses**
##### Structure des documents

{
  "product_id": 1,
  "product_name": "Chai",
  "quantity_per_unit": "10 boxes x 20 bags",
  "unit_price": 18.0,
  "units_in_stock": 39,
  "discontinued": false,
  "category": {
    "category_id": 1,
    "category_name": "Beverages",
    "description": "Soft drinks, coffees, teas"
  },
  "supplier": {
    "supplier_id": 1,
    "company_name": "Exotic Liquids",
    "contact_name": "Charlotte Cooper",
    "country": "UK"
  }
}

{
  "order_id": 10248,
  "order_date": "1996-07-04",
  "required_date": "1996-08-01",
  "shipped_date": "1996-07-16",
  "freight": 32.38,
  "ship_name": "Vins et alcools Chevalier",
  "ship_country": "France",
  "customer": {
    "customer_id": "VINET",
    "company_name": "Vins et alcools Chevalier",
    "contact_name": "Paul Henriot",
    "country": "France"
  },
  "employee": {
    "employee_id": 5,
    "first_name": "Steven",
    "last_name": "Buchanan"
  },
  "shipper": {
    "shipper_id": 3,
    "company_name": "Federal Shipping"
  },
  "order_details": [
    {
      "product_id": 11,
      "product_name": "Queso Cabrales",
      "quantity": 12,
      "unit_price": 14.0,
      "discount": 0.0
    },
    {
      "product_id": 42,
      "product_name": "Singaporean Hokkien Fried Mee",
      "quantity": 10,
      "unit_price": 9.8,
      "discount": 0.0
    }
  ]
}

3. **Définir les types de données pour chaque champ** :
    - Identifiez les types appropriés (`text`, `keyword`, `date`, `numeric`, etc.).
    - Décidez quels champs doivent être analysés pour la recherche full-text.

   **Réponses**
##### Types appropriés

🔸 Index products — Types de champs recommandés
Champ	Type Elasticsearch	Description / Usage
product_id	integer	Identifiant unique (non analysé).
product_name	text + keyword	Recherches full-text (text) + tri ou filtres exacts (keyword).
quantity_per_unit	text	Information descriptive, peu utilisée en recherche.
unit_price	float	Pour les filtres, tris, agrégations.
units_in_stock	integer	Pour monitoring ou filtres de disponibilité.
discontinued	boolean	Statut du produit.
category.category_id	integer	Identifiant de la catégorie.
category.category_name	keyword	Utilisé en filtre ou agrégation (nom exact).
category.description	text	Description libre, non utilisée en filtre.
supplier.supplier_id	integer	Identifiant fournisseur.
supplier.company_name	keyword	Pour filtres et agrégations.
supplier.country	keyword	Pour filtrage géographique.

🔸 Index orders — Types de champs recommandés
Champ	Type Elasticsearch	Description / Usage
order_id	integer	Identifiant unique.
order_date	date	Pour filtres ou agrégations temporelles.
required_date	date	Pour analyses logistiques.
shipped_date	date	Pour analyser les délais.
freight	float	Montant de la livraison, utilisable pour analyse des coûts.
ship_name	text	Nom du destinataire, peu utilisé en recherche.
ship_country	keyword	Filtrage géographique.
customer.customer_id	keyword	Clé étrangère pour filtre exact.
customer.company_name	text + keyword	Recherche par nom + filtre exact.
customer.country	keyword	Pour filtres régionaux.
employee.employee_id	integer	Identifiant de l’employé.
employee.first_name	text	Recherche potentielle par nom.
employee.last_name	text	Idem.
shipper.company_name	keyword	Pour filtres ou statistiques par transporteur.
order_details[].product_id	integer	Produit commandé (utile pour analyses).
order_details[].product_name	text + keyword	Recherche et filtres.
order_details[].quantity	integer	Quantité commandée.
order_details[].unit_price	float	Prix unitaire pour analyse des revenus.
order_details[].discount	float	Remise appliquée.

##### Champs à analyser pour la recherche full-text

product_name

customer.company_name

order_details.product_name

(éventuellement) employee.first_name, employee.last_name si des recherches sont prévues

4. **Configurer les analyseurs appropriés** :
    - Définir un analyseur personnalisé pour les noms de produits.
    - Configurer les options d'analyse appropriées pour les champs textuels.

   **Réponses**
##### Analyseur personnalisé

edge_ngram :

"settings": {
  "analysis": {
    "analyzer": {
      "autocomplete_analyzer": {
        "type": "custom",
        "tokenizer": "autocomplete_tokenizer",
        "filter": [
          "lowercase"
        ]
      },
      "autocomplete_search_analyzer": {
        "type": "custom",
        "tokenizer": "standard",
        "filter": [
          "lowercase"
        ]
      }
    },
    "tokenizer": {
      "autocomplete_tokenizer": {
        "type": "edge_ngram",
        "min_gram": 2,
        "max_gram": 20,
        "token_chars": [
          "letter",
          "digit"
        ]
      }
    }
  }
}

product_name :

"mappings": {
  "properties": {
    "product_name": {
      "type": "text",
      "analyzer": "autocomplete_analyzer",
      "search_analyzer": "autocomplete_search_analyzer"
    }
  }
}


##### Options d'analyse appropriées

| Champ                        | Usage recherché                     | Type d'analyse recommandé                |
| ---------------------------- | ----------------------------------- | ---------------------------------------- |
| `product_name`               | Recherche partielle, autocomplétion | `edge_ngram` via `autocomplete_analyzer` |
| `customer.company_name`      | Recherche exacte et partielle       | `standard` ou `custom`                   |
| `order_details.product_name` | Recherche dans l’historique         | `standard` ou `autocomplete_analyzer`    |
| `category.category_name`     | Filtrage exact                      | `keyword`                                |
| `supplier.company_name`      | Filtrage et tri                     | `keyword` ou `lowercase normalizer`      |

exemple :

"product_name": {
  "type": "text",
  "analyzer": "autocomplete_analyzer",
  "search_analyzer": "autocomplete_search_analyzer",
  "fields": {
    "raw": {
      "type": "keyword",
      "normalizer": "lowercase_normalizer"
    }
  }
}

5. **Créer le mapping dans Elasticsearch** :
    - Pour l'index `products`.
    - Pour l'index `orders`.

   **Réponses**
##### Mapping

orders :

{
  "mappings": {
    "properties": {
      "order_id": { "type": "integer" },
      "order_date": { "type": "date" },
      "customer": {
        "properties": {
          "id": { "type": "keyword" },
          "company_name": { "type": "keyword" }
        }
      },
      "order_details": {
        "type": "nested",
        "properties": {
          "product": {
            "properties": {
              "id": { "type": "integer" },
              "name": { "type": "keyword" }
            }
          },
          "quantity": { "type": "integer" },
          "unit_price": { "type": "float" }
        }
      }
    }
  }
}

products :

{
  "mappings": {
    "properties": {
      "product_id": { "type": "integer" },
      "name": {
        "type": "text",
        "fields": {
          "keyword": { "type": "keyword" }
        }
      },
      "price": { "type": "float" },
      "category": {
        "properties": {
          "id": { "type": "integer" },
          "name": { "type": "keyword" }
        }
      },
      "supplier": {
        "properties": {
          "id": { "type": "integer" },
          "name": { "type": "keyword" }
        }
      }
    }
  }
}

### Partie 3 : Transformation et indexation des données (90 min)
1. **Écrire les requêtes SQL pour extraire les données avec leurs relations** :
    - Requêtes pour récupérer les produits avec catégories et fournisseurs.
    - Requêtes pour récupérer les commandes avec clients et détails.
    
   **Réponses**
##### Requêtes produits et commandes

SELECT 
  p.ProductID, 
  p.ProductName, 
  c.CategoryName, 
  s.CompanyName AS SupplierName
FROM Products p
JOIN Categories c ON p.CategoryID = c.CategoryID
JOIN Suppliers s ON p.SupplierID = s.SupplierID;

SELECT 
  o.OrderID, 
  o.OrderDate, 
  c.CompanyName, 
  od.UnitPrice, 
  od.ProductID
FROM Orders o
JOIN Customers c ON o.CustomerID = c.CustomerID
JOIN [Order Details] od ON o.OrderID = od.OrderID;

2. **Créer un script Node.js de transformation et d'indexation** :
    - Configurer la connexion à la base de données MySQL/PostgreSQL.
    - Configurer la connexion à Elasticsearch.
    - Développer la logique de transformation des données relationnelles en JSON.
    - Implémenter l'indexation en masse (bulk indexing).
    
   **Réponses**
##### Script

require('dotenv').config();
const sql = require('mssql');
const { Client } = require('@elastic/elasticsearch');

// Config SQL Server
const dbConfig = {
    server: process.env.DB_SERVER,
    database: process.env.DB_DATABASE,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    options: {
        encrypt: false,
        trustServerCertificate: true
    }
};

// Config Elasticsearch
const esClient = new Client({ node: process.env.ES_NODE });

async function fetchDataFromSQL() {
    try {
        let pool = await sql.connect(dbConfig);
        let result = await pool.request().query('SELECT * FROM products');
        return result.recordset;
    } catch (err) {
        console.error('Erreur SQL :', err);
        throw err;
    }
}

function transformToJSON(record) {
    return {
        product_id: record.product_id,
        product_name: record.product_name,
        supplier_id: record.supplier_id,
        category_id: record.category_id,
        quantity_per_unit: record.quantity_per_unit,
        unit_price: record.unit_price,
        units_in_stock: record.units_in_stock,
        units_on_order: record.units_on_order,
        reorder_level: record.reorder_level,
        discontinued: record.discontinued
    };
}

async function bulkIndex(data) {
    const body = data.flatMap(doc => [{ index: { _index: process.env.ES_INDEX } }, doc]);

    const { body: bulkResponse } = await esClient.bulk({ refresh: true, body });

    if (bulkResponse.errors) {
        const errors = bulkResponse.items.filter(item => item.index && item.index.error);
        console.error('Erreurs d\'indexation :', errors);
    } else {
        console.log(`✅ ${data.length} produits indexés`);
    }
}

async function main() {
    try {
        const rawData = await fetchDataFromSQL();
        const jsonData = rawData.map(transformToJSON);
        await bulkIndex(jsonData);
    } catch (err) {
        console.error('Erreur dans le script :', err);
    } finally {
        sql.close();
    }
}

main();

##### Modification du .env

DB_SERVER=localhost
DB_DATABASE=northwind
DB_USER=youruser
DB_PASSWORD=yourpassword
ES_NODE=http://localhost:9200
ES_INDEX=products
    
3. **Exécuter l'indexation initiale** :
    - Exécutez le script pour indexer tous les produits.
    - Exécutez le script pour indexer toutes les commandes.
    
   **Réponses**
##### Exécution du script

On a rencontré des erreurs : on c'est aidé de la doc pour les résoudre.
- Problèmes pour se connecter à la bdd.
- Solution : création d'accès authentification sql, attribution de droits, etc.. mais problèmes persistants au lancement du script.

4. **Vérifier les résultats** :
    - Vérifiez le nombre de documents indexés.
    - Examinez quelques documents pour s'assurer de leur structure correcte.
    
   **Réponses**
##### Requête API

On utilise Postman : 
- GET localhost:9200/products/_count
- GET localhost:9200/products/_search?size=3

### Partie 4 : Test et optimisation (45 min)
1. **Concevoir et exécuter différentes requêtes de recherche** :
    - Recherche full-text sur les noms de produits.
    - Filtrage par catégorie.
    - Requêtes combinées avec filtres et tris.
    - Recherche et agrégations pour les statistiques.
    
   **Réponses**
##### x

x

2. **Évaluer la pertinence des résultats** :
    - Analysez les scores de pertinence.
    - Vérifiez si les résultats correspondent aux attentes.
    
   **Réponses**
##### x

x

3. **Optimiser le mapping si nécessaire** :
    - Ajustez les analyseurs ou les types de champs.
    - Modifiez la structure des documents si nécessaire.
    
   **Réponses**
##### x

x

4. **Discuter des améliorations potentielles** :
    - Analysez ce qui pourrait être amélioré.
    - Discutez des limites de votre approche actuelle.
    
   **Réponses**
##### x

x

-----------

## Extensions possibles

Si vous terminez rapidement, voici quelques suggestions d'extensions :

1. **Création d'une API REST avec Express.js** :
    - Développez une API RESTful avec Express.js pour interroger vos index Elasticsearch.
    - Implémentez les routes suivantes :
      - Recherche de produits avec filtres et pagination.
      - Recherche de commandes avec filtres et pagination.
      - Route d'autocomplétion pour les noms de produits.

2. **Création d'une interface utilisateur simple** :
    - Développez une interface utilisateur HTML/CSS/JavaScript pour interagir avec votre API.
    - Fonctionnalités à implémenter :
      - Barre de recherche avec autocomplétion.
      - Filtres de catégorie et de prix.
      - Affichage des produits sous forme de grille.
      - Pagination des résultats.
      - Affichage des détails des commandes.

3. **Ajout d'analyseurs spécifiques** :
    - Améliorez la recherche en configurant des analyseurs spécialisés :
      - Analyseur n-gram pour l'autocomplétion.
      - Configuration de synonymes pour améliorer la pertinence.
      - Analyseur phonétique pour la recherche approximative.

4. **Mise en place d'une indexation incrémentale** :
    - Développez un système d'indexation qui ne met à jour que les données modifiées :
      - Ajoutez une colonne `modified_date` aux tables de votre base de données.
      - Développez un script qui n'indexe que les enregistrements modifiés depuis la dernière indexation.
      - Implémentez un mécanisme pour suivre la dernière date d'indexation.

5. **Gestion des synonymes** :
    - Améliorez la pertinence de la recherche en configurant des synonymes :
      - Définissez des synonymes pour les catégories de produits.
      - Définissez des synonymes pour les termes courants dans les noms de produits.
      - Testez l'impact des synonymes sur les résultats de recherche.

-----------

## Ressources utiles

- [Documentation officielle d'Elasticsearch pour Node.js](https://www.elastic.co/docs/reference/elasticsearch/clients/javascript/)
- [Guide de référence des mappings](https://www.elastic.co/guide/en/elasticsearch/reference/current/mapping.html)
- [Documentation sur les analyzers](https://www.elastic.co/guide/en/elasticsearch/reference/current/analysis.html)
- [Guide de l'API de recherche](https://www.elastic.co/guide/en/elasticsearch/reference/current/search-search.html)
- [Documentation Express.js](https://expressjs.com/)

-----------

## Évaluation

L'évaluation de ce TP portera sur :
- La qualité du mapping Elasticsearch (**30%**).
- La pertinence de la dénormalisation effectuée (**30%**).
- L'efficacité du script d'extraction et d'indexation (**20%**).
- La pertinence des requêtes de test (**20%**).

-----------

## Notes

Ce TP est conçu pour être réalisé en groupe. N'hésitez pas à échanger vos idées et à poser des questions. L'objectif est d'apprendre ensemble et de partager vos expériences.

**Bon courage (pour la correction) !**