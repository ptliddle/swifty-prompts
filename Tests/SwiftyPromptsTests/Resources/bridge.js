#!/usr/bin/env node

// This script acts as a bridge between Swift and Node.js modules
// It reads JSON requests from stdin and writes JSON responses to stdout

const readline = require('readline');
const path = require('path');
const fs = require('fs');

// Set up module directory if provided
let moduleDir = process.argv[2];
if (moduleDir) {
  process.env.NODE_PATH = moduleDir;
  require('module').Module._initPaths();
}

// Create readline interface
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
  terminal: false
});

// Store loaded modules
const modules = {};

// Process each line from stdin
rl.on('line', (line) => {
  try {
    const request = JSON.parse(line);
    let response = {};

    switch (request.type) {
      case 'importModule':
        response = importModule(request.module);
        break;
      case 'functionCall':
        response = callFunction(request.module, request.function, request.arguments);
        break;
      default:
        response = { error: `Unknown request type: ${request.type}` };
    }

    // Write response as JSON
    process.stdout.write(JSON.stringify(response) + '\n');
  } catch (error) {
    // Write error as JSON
    process.stdout.write(JSON.stringify({ error: error.message }) + '\n');
  }
});

// Import a module
function importModule(moduleName) {
  try {
    modules[moduleName] = require(moduleName);
    return { success: true };
  } catch (error) {
    return { error: `Failed to import module '${moduleName}': ${error.message}` };
  }
}

// Call a function in a module
function callFunction(moduleName, functionName, args) {
  try {
    // Import module if not already imported
    if (!modules[moduleName]) {
      const importResult = importModule(moduleName);
      if (importResult.error) {
        return importResult;
      }
    }

    const module = modules[moduleName];
    
    // Get the function
    let func = module;
    const parts = functionName.split('.');
    for (const part of parts) {
      if (func && typeof func === 'object') {
        func = func[part];
      } else {
        return { error: `Function '${functionName}' not found in module '${moduleName}'` };
      }
    }

    if (typeof func !== 'function') {
      return { error: `'${functionName}' is not a function in module '${moduleName}'` };
    }

    // Call the function
    const result = func.apply(null, args || []);
    
    // Handle promises
    if (result && typeof result.then === 'function') {
      return result
        .then(value => ({ result: value }))
        .catch(error => ({ error: error.message }));
    }
    
    return { result };
  } catch (error) {
    return { error: `Error calling function '${functionName}' in module '${moduleName}': ${error.message}` };
  }
}

// Handle process termination
process.on('SIGTERM', () => {
  rl.close();
  process.exit(0);
});

// Notify Swift that the bridge is ready
process.stdout.write(JSON.stringify({ status: 'ready' }) + '\n');
