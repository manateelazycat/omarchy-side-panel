// SPDX-License-Identifier: GPL-3.0-only
const fs = require('node:fs');
const {trace} = require('../Ui/TraySvg.js');
const [input,output] = process.argv.slice(2);
const [width,height] = JSON.parse(fs.readFileSync(input+'.json','utf8'));
fs.writeFileSync(output,trace(fs.readFileSync(input),width,height));
