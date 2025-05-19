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