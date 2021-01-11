require('dotenv').config()
const mariadb = require("mariadb");

const dgPool = mariadb.createPool({
  host: '127.0.0.1',
  user: 'root',
  database: 'duckguessr',
  password: process.env.MYSQL_PASSWORD,
  port: 33061,
  connectionLimit: 5
});
const coaPool = mariadb.createPool({
  host: '127.0.0.1',
  user: 'root',
  database: 'coa',
  password: process.env.MYSQL_PASSWORD,
  port: 64000,
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
