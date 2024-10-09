/*** 
This file is part of https://github.com/KazKobara/plot_openssl_speed
Copyright (C) 2024 National Institute of Advanced Industrial Science and Technology (AIST).
All Rights Reserved.

usage:
  $ node this_js [http_src]

example: 
  $ node html_table2dsv.mjs 'Post-Quantum_signatures_zoo.mhtml'

  $ node html_table2dsv.mjs 'https://bench.cr.yp.to/results-sign/amd64-hertz.html'
  $ node html_table2dsv.mjs 'https://pqshield.github.io/nist-sigs-zoo/#performance'

  $ node html_table2dsv.mjs "$(echo -e "<table><tr><td>1-1</td><td>1-=\n2</td></tr><tr><td>2=\n-1</td><td>2-2</td></tr></table>")"
  Note: test shall include "=\n" such as:
*/

/*
// CommonJS
const puppeteer = require('puppeteer');
const path = require('path');
*/ 
// ES Module
import puppeteer from 'puppeteer';
import path from 'path';

//function html_table2sv(arg) { // CommonJS
export default function html_table2sv(arg) {  // ES Module
  const __dirname = import.meta.dirname       // ES Module
  // console.log(String(arg).toLowerCase());
  /* for test
  arg = `
  <html>
      <body>
        <table>
  <tr><td>ML-DSA (Dilithium)</td><td>ML-DSA-65</td><td>3</td><td style=3D"text=
  -align: right">1,952</td><td style=3D"text-align: right">3,309</td><td styl=
  e=3D"text-align: right">5,261</td></tr><tr><td>ML-DSA (Dilithium)</td><td>M=
  L-DSA-44</td><td>2</td><td style=3D"text-align: right">1,312</td><td style=
  =3D"text-align: right">2,420</td><td style=3D"text-align: right">3,732</td>=
  </tr>
        </table>
      </body>
  </html>`;
 */
  let html_src;
  switch (true) {
    case /^https?:\/\//.test(arg):
      html_src = arg;
      break;
    // case /^(\.\/|\/|[a-zA-Z]:\\).*\.m?html?/.test(arg):
    case /.*\.m?html?/.test(arg):
      //const html_src_type = 'file'
      // ./ / c:\ etc.
      html_src = path.join('file://', __dirname, arg);
      break;
    case /<table>([\s\S]*)<\/table>/.test(String(arg).toLowerCase()):
      // const html_src_type = 'val'
      html_src = `data:text/html, ${arg}`;
      break;
    default:
      // console.log(process.argv.length)
      //if ( process.argv.length <= 2 ){
      if ( ! arg ){
        console.error("Give 'html_src' as the argument!")
      } else {
        console.error("Unknown html_src_type!");
      };
      process.exit(1);
  }

  //const res = (async () => {
  (async () => {
    // const browser = await puppeteer.launch();
    const browser = await puppeteer.launch({
      headless: 'new',
      // `headless: true` (default) enables old Headless;
      // `headless: 'new'` enables new Headless;
      // `headless: false` enables "headful" mode.  
    });
    const page = await browser.newPage();
    //await page.goto(html_src);
    await page.goto(html_src, {waitUntil: 'networkidle0'});
    //await page.screenshot({ path: 'screen.png' });
    const data = await page.evaluate(() => {
      // const tds = Array.from(document.querySelectorAll('table tr td'))
      const tds = Array.from(document.querySelectorAll('table tr'))
      return tds.map(td => td.innerText)
    });

    /* console.log(data);
    for (let i = 0; i < data.length; i++) {
      console.log(data[i].replace(/=(\t| )/gm, ""));
    }
    */
    // console.log(data.join("\n").replace(/=(\t| )/gm, ""));
    console.info(data.join("\n").replace(/=(\t| )/gm, ""));
    await browser.close();
    //const ret = await Promise.all([2000]);
    //return data.join("\n").replace(/=(\t| )/gm, "");

  })();
  //return res;
};


/*** main ***/
/*
for(let i = 0;i < process.argv.length; i++){
  console.log("argv[" + i + "] = " + process.argv[i]);
}
process.exit(1);
*/
const arg = process.argv[2];
html_table2sv(arg);
// console.log(html_table2sv(arg));

// module.exports = html_table2sv;  // CommonJS
