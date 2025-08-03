const path = require('path');
const TerserPlugin = require('terser-webpack-plugin');
const { WebpackManifestPlugin } = require('webpack-manifest-plugin');

const isProduction = process.env.NODE_ENV === 'production';

module.exports = {
  mode: isProduction ? 'production' : 'development',
  entry: {
    islands_bundle: ['./app/javascript/islandjs/index.js']
  },
  externals: {
  // IslandJS managed externals - do not edit manually
},
  output: {
    filename: '[name].js',
    path: path.resolve(__dirname, 'public'),
    publicPath: '/',
    clean: false
  },
  module: {
    rules: [
      {
        test: /\.(js|jsx)$/,
        exclude: /node_modules/,
        use: {
          loader: 'babel-loader',
          options: {
            presets: ['@babel/preset-env', '@babel/preset-react']
          }
        }
      }
    ]
  },
  resolve: {
    extensions: ['.js', '.jsx']
  },
  optimization: {
    minimize: isProduction,
    minimizer: [new TerserPlugin()]
  },
  plugins: [
    new WebpackManifestPlugin({
      fileName: 'islands_manifest.json',
      publicPath: '/'
    })
  ],
  devtool: isProduction ? false : 'source-map'
};
