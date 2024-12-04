// /** @type {import("ts-jest/dist/types").InitialOptionsTsJest} */
// module.exports = {
//     preset: "ts-jest",
//     moduleNameMapper: {
//       "^(\\.{1,2}/.*)\\.js$": "$1",
//     },
//     testEnvironment: "node",
    
//     // testPathIgnorePatterns: ["dist/*", "indigg/*"],
//     collectCoverage: true,
//     setupFiles: ["dotenv/config"],
//     coverageThreshold: {
//       global: {
//         branches: 50, // 90,
//         functions: 50, // 95,
//         lines: 50, // 95,
//         statements: 50, // 95,
//       },
//     },
//     // To help avoid exhausting all the available fds.
//     maxWorkers: 4,
//     globalSetup: "./tests/preTest.js",
//     globalTeardown: "./tests/postTest.js",
//   };
  


module.exports = {
    preset: "ts-jest",
    // moduleNameMapper: {
    //   "^(\\.{1,2}/.*)\\.js$": "$1",
    // },
    testEnvironment: "node",
    testMatch: ['**/__test__/**/*.+(ts|tsx|js|jsx)', '**/?(*.)+(spec|test).+(ts|tsx|js|jsx)'],
    // testPathIgnorePatterns: ["dist/*", "indigg/*"],
    collectCoverage: true,
    // setupFiles: ["dotenv/config"],
    // coverageThreshold: {
    //   global: {
    //     branches: 50, // 90,
    //     functions: 50, // 95,
    //     lines: 50, // 95,
    //     statements: 50, // 95,
    //   },
    // },
    // To help avoid exhausting all the available fds.
    // maxWorkers: 4,
    // globalSetup: "./tests/preTest.js",
    // globalTeardown: "./tests/postTest.js",
    
      // "collectCoverage": true,
      // "coverageReporters": ["json", "lcov", "text", "clover"],
      // "coverageDirectory": "coverage",
    // "reporters": [
    //   "default",
    //   ["jest-allure", {
    //     "outputDi3rectory": "allure-results",
    //     "disableWebdriverStepsReporting": true,
    //     "disableWebdriverScreenshotsReporting": true
    //   }]
    // ]

    
      "reporters": ["default", "jest-allure2-reporter"],
      "setupFilesAfterEnv": ["jest-allure2-adapter"]
    
    
    // "reporters": [
    //   "default",
    //   "jest-allure2-adapter"
    // ],
  //   reporters: ['spec',['allure', {
  //     outputDir: 'allure-results',
  //     disableWebdriverStepsReporting: true,
  //     disableWebdriverScreenshotsReporting: true,
  // }]],

  };