var webpack = require('webpack');
var CopyWebpackPlugin = require('copy-webpack-plugin');
var path = require('path');

var BUILD_DIR = path.resolve(__dirname, 'target/ui');
var APP_DIR = path.resolve(__dirname, 'src/main/js');

var config = {
    entry: APP_DIR + '/index.jsx',
    output: {
        path: BUILD_DIR + '/js',
        filename: 'app.js'
    },
    module : {
        loaders : [
            {
                test : /\.jsx$/,
                include : APP_DIR,
                loader : 'babel'
            }
        ]
    },
    plugins: [
        new CopyWebpackPlugin([{
            from: APP_DIR + '/*.html',
            to: BUILD_DIR,
            flatten: true
        }])
    ]
};

module.exports = config;