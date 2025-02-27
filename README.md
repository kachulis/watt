# Watt

***WDL Automated Testing Tool***

## Overview

Watt is a command line tool for automating the testing of WDL workflows. It's supports customization of directory structure, testing for failure, full file comparison across `File` type outputs (even when gzipped, but not other types of compressed), and high-level summaries including explanations for why tests failed. It can be run concurrently using multiprocessing, and fits nicely into a CI framework by allowing configurable filtering on which tests should be run (provided by the user).

Click to jump to a specific section below.
1. [Getting Started](#getting-started)
2. [The Test Configuration File](#the-test-configuration-file)
3. [Usage and Runtime Options](#usage-and-runtime-options)
   4. [Options](#options)
   5. [Example Usage](#example-usage)
   6. [Interpreting the Results](#interpreting-the-results)
7. [Testing Watt](#testing-watt)
8. [Non-Use Cases](#non-use-cases)
9. [Developer's Notes](#developers-notes)

## Getting Started

To use this script, follow these steps:
1. Copy the `watt.py` script into your repo.
2. Create test inputs and outputs JSON files (along with any necessary test files).
3. Make a `wdl_test_config.yml` file holding metadata for existing tests in your repo.
4. Set up the environment: make a virtual environment with the required packages. For example, copy the `requirements.txt` here
to your own repo's `test_requirements.txt` and then run:
```
python -m venv venv
source venv/bin/activate
pip install -r test_requirements.txt
```
5. Run using `python watt.py [ARGS]` with possible options described below.

## The Test Configuration File

The configuration file controls how Watt accesses the WDL scripts along with the test data. By default, it should be located in the runtime directory named `watt_config.yml`, but this can be configured with a flag. 

The file uses `yaml` format, with each top-level entry corresponding to a different test. An example test might be recorded as:
``` 
workflow_name:
  path: "/workflows/something.wdl"
  tests:
    test_name:
      test_inputs: "/tests/inputs.json"
      expected_outputs: "/tests/outputs.json"
```
The workflow_name and test_name can be used separately or together to filter which tests you'd like to run when invoking Watt. See below for details.

The `path` points to the WDL to be run for the test, and the `test_inputs` are given to Cromwell to configure that run. The `expected_outputs` is what should match the Cromwell outputs JSON. You can set this field to `null` in the configuration to mean you expect the Cromwell job to fail for the given inputs to check e.g. error handling or edge cases in your workflow. 
You can set an output in the `expected_outputs` json to `null` tell Watt not to compare that output.
In this case, the test will still fail if the specified output is not produced by the workflow, but it will not check its value against anything.
You can also tell a comparison to ignore certain lines in a particular output file by setting the expected output value in `expected_oputputs` to an object with keys `file` and `line_skip_regex`.
Any line which matches the regex in the `line_skip_regex` field will be ignored in the comparison.

Othewise, each key will have its value compared to the matching key in the other file. See [Interpreting the Results](#interpreting-the-results) below for the different types of test outcomes that can happen. 

## Usage and Runtime Options

### Options

* `-h`: help menu
* `-e`: [REQUIRED] path to execution engine jar (i.e. Cromwell jar); checks `EXECUTION_ENGINE` environment variable by default
* `-w`: restrict to workflow(s) with given name(s)
* `-t`: restrict to test(s) with give name(s)
* `--executor-log-prefix`: prefix to use for writing execution engine logs (defaults to `watt_logs/cromwell`)
* `-c`: location of Watt config file (default: `watt_config.yml`)
* `-l`: location to write Watt logs (defaults to stdout)
* `-p`: number of processes to use for testing

### Example Usage

You can see the `watt_config.yml` example provided in this repo to see some example tests. The test data is stored in the `/tests` directory. You can run
``` 
python watt.py -e <cromwell_path>
```
to run all tests in this repo.

If you have a lot of tests, you probably don't want to run them all when just developing or modifying a few workflows. You can restrict the tests run either by `workflow_name` or `test_name`, defined by the config file. For example, this repo has tests organized in the following way:

| WDL | workflow_name | test_name          |
| ---- | -------------|--------------------|
| workflows/say_hello.wdl | say_hello | simple             |
| workflows/say_hello.wdl | say_hello | mismatch           |
| workflows/say_hello.wdl | say_hello | file_type_mismatch |
| workflows/extract_stat.wdl | extract_stat | simple             |
| workflows/extract_stat.wdl | extract_stat | mismatch           |
| workflows/extract_stat.wdl | extract_stat | expect_fail        |
| workflows/extract_stat.wdl | extract_stat | array_shape_mismatch|
| workflows/bad_workflow.wdl | bad_workflow | bad_workflow |

So for example, if you were to run
``` 
python watt.py -e <cromwell> -w say_hello
```
this would run the first three tests only. You can add the `-p 3` flag to run this in 3 processes which runs significantly faster than with just 1 process (default), at the cost of some out-of-order logs. The final summary will still be in the right order.

Another example: if you run
``` 
python watt.py -e <cromwell> -t simple
```
this would run the `say_hello/simple` test and the `extract_stat/simple` test. You can combine these flags to run a specific test, like
``` 
python watt.py -e <cromwell> -w say_hello -t simple
```
to just run the first test.

Both flags accept a list of inputs, so e.g.
```
python watt.py -e <cromwell> -w say_hello,extract_stat
```
would run all tests except the `bad_workflow/bad_workflow` test.

### Interpreting the Results

If the Watt logs aren't redirected to a file, they will be printed to stdout during runtime. Some logs will tell you the status of current test, but a final summary will be printed at the end in the correct order (especially if running concurrently with multiprocessing). In this repo, the summary should look like:
``` 
Final Test Summary (Workflow Name / Test Name: Result)
  say_hello/simple
    Keys unique to expected output: 0
    Keys unique to actual output: 0
    Matches: 1
    Mismatches: 0
    ArrayShapeMismatches: 0
    FileTypeMismatches: 0


  say_hello/mismatch
    Keys unique to expected output: 0
    Keys unique to actual output: 0
    Matches: 0
    Mismatches: 1 -- say_hello.announcement do not match <====================!
    ArrayShapeMismatches: 0
    FileTypeMismatches: 0


  say_hello/file_type_mismatch
    Keys unique to expected output: 0
    Keys unique to actual output: 0
    Matches: 0
    Mismatches: 0
    ArrayShapeMismatches: 0
    FileTypeMismatches: 1 -- say_hello.announcement do not match <====================!


  say_hello/compress_file
    Keys unique to expected output: 0
    Keys unique to actual output: 0
    Matches: 1
    Mismatches: 0
    ArrayShapeMismatches: 0
    FileTypeMismatches: 0


  extract_stat/simple
    Keys unique to expected output: 0
    Keys unique to actual output: 0
    Matches: 4
    Mismatches: 0
    ArrayShapeMismatches: 0
    FileTypeMismatches: 0


  extract_stat/mismatch
    Keys unique to expected output: 0
    Keys unique to actual output: 0
    Matches: 1
    Mismatches: 3 -- extract_stat.name extract_stat.stat extract_stat.wdl_table do not match <====================!
    ArrayShapeMismatches: 0
    FileTypeMismatches: 0


  extract_stat/expect_fail
    Success (expected no outputs)


  extract_stat/array_shape_mismatch
    Keys unique to expected output: 0
    Keys unique to actual output: 0
    Matches: 1
    Mismatches: 0
    ArrayShapeMismatches: 3 -- extract_stat.name extract_stat.entries extract_stat.wdl_table do not match <====================!
    FileTypeMismatches: 0


  bad_workflow/bad_workflow
    Failure (Cromwell failed to finished unexpectedly)


Some tests failed. See logs for full summary.
```
Running with `-p 9` takes less than 2 minutes. The tool returns exit code 1 if any test failed, and otherwise 0. There are a few types of test results that can happen:
1. `Match`: Every expected output matched the actual Cromwell output, with keys perfectly aligned, file contents agree if appropriate, etc. This is the only way a test passes other than #6 below.
2. `Keys unique`: Some keys in the expected or actual outputs JSONs were unique to one file but not the other. If this happens, the keys unique to either side would be printed here.
3. `Mismatch`: The keys lined up properly, but some value was not equal, e.g. some file contents were off, integers were not equal, etc.
4. `ArrayShapeMismatch`: One side of a comparison with matching keys had an array shape not matching the other side, e.g. `[1, 2, 3, 4] != [[1, 2], [3, 4]]`. 
5. `FileTypeMismatch`: One side of the comparison seemed to be a file while the other side was not, so it did not make sense to try to compare them. File types are inferred heuristically by checking if the raw string exists as a path, and if so the type is assumed to be file.
6. `Success (expected no outputs)`: If the config file had a `null` for the expected outputs, then the test succeeds only if the job fails.
7. `Failure (Cromwell failed to finish unexpectedly)`: In this case, Cromwell failed during runtime, but this wasn't expected (there was a non-null value for expected outputs).

By looking at the examples in the repo, you can see an example test configuration and workflow that would produce any of these errors.


## Testing Watt

This repository contains a sample `watt_config.yml` along with some toy example workflows and test data so you can demo running the tool before commiting to setting it up in your own repo. It also demonstrates some ideas about how you might structure your tests in your own repo. Simply clone this repo, and run `python watt.py`, toggling the arguments to select for which tests to run (or leave empty to run them all). 

## Non-Use Cases

This tool should *not* be used for:
* validating your WDLs have proper syntax (use [womtool](https://cromwell.readthedocs.io/en/develop/WOMtool/))
* linting your WDLs (try [sprocket](https://github.com/stjude-rust-labs/sprocket))
* catching regressions in performance for complex workflows (use [Carrot](https://github.com/broadinstitute/carrot))
* testing WDLs which have their outputs change slightly over time and would require a wrapper WDL to test if outputs have only changed within a threshold (use [Carrot](https://github.com/broadinstitute/carrot)); Watt only currently supports exact matching on outputs (although could test wrapper test WDLs using the same techniques if you really want)

## Developers Notes

Hopefully one day this tool will be superseded by more robust tool which does some WDL parsing to infer data types, and other fancy improvements, which is why this tool isn't currently available as a Python package. In the meantime, you can open an issue/submit a PR if you find any bugs or easy extra features to add. I'll tag releases so you can keep your script pinned to a fixed version. You can "watch" the repo to stay up to date on new releases.
