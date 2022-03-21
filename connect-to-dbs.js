require('dotenv').config()
const mariadb = require("mariadb");

const dgPool = mariadb.createPool({
  host: process.env.MYSQL_HOST_DG,
  user: 'root',
  database: 'duckguessr',
  password: process.env.MYSQL_PASSWORD,
  port: process.env.MYSQL_PORT_DG,
  connectionLimit: 5
});
const coaPool = mariadb.createPool({
  host: process.env.MYSQL_HOST_COA,
  user: 'root',
  database: 'coa',
  password: process.env.MYSQL_PASSWORD,
  port: process.env.MYSQL_PORT_COA,
  connectionLimit: 5,
  multipleStatements: true
});


exports.connect = () => new Promise((resolve, reject) => {
  coaPool.getConnection().then(coaConnection => {
    dgPool.getConnection().then(dgConnection => {
      resolve({coaConnection, dgConnection})
    }).catch(err => {
      coaConnection && coaConnection.end();
      reject(err)
    });
  }).catch(err => {
    reject(err)
  });
})
