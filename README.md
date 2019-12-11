# adas-pro-sivic
This repository contains source code for search-based software testing of a pedestrian detection system using the virtual prototyping platform Pro-SiVIC. We hope that the example code provided can help future developers and researchers getting started with software testing using Pro-SiVIC. The examples use Data Distribution Service (DDS) for communication between Pro-SiVIC and MATLAB and Simulink, resepctively.

The corresponding research article is currently in preparation (Dec 2019).

The repository contains four main parts:

- `sbst_pedestrian_detection_system`: An adaptation of the original NSGA-II algorithm for search-based testing in Pro-SiVIC.
- `utils`: Various scripts that can be used to reproduce our results.
- `example_prosivic_matlab`: Examples of DDS communication between Pro-SiVIC and MATLAB applications.
- `example_prosivic_simulink`: An example of DDS communication between Pro-SiVIC and Simulink blocks.

## sbst_pedestrian_detection_system
This is the core component of the repository, demonstrating how NSGA-II can be used to generate critical test scenarios for a pedestrian detection system simulated using Pro-SiVIC. 

### Pedestrian detection system
The pedestrian detection system (PDS) under test in the research publication is a proprietary Simulink solution that we cannot publish on GitHub. The PDS uses a combination of computer vision and radar signal characteristics to detect pedestrians in front of the vehicle. To support replication of our work, we provide a mock implementation of the PDS component in Simulink. Our mock implementation provides a random value for the detection (0 or 1) and a constant time to collision (4 s). While the detection value is not used in the objective functions (described next), the constant time to collision will effectively remove one of the three objective functions. 

### Objective functions
The implementation shows how NSGA-II can be for multi-objective optimization, in this case to generate test scenarios for the given scene that minimize three objective functions:
- OF1 = the minimum distance between the pedestrian and the car (`min_dist`)
- OF2 = the minimum time to collision (`min_ttc`)
- OF3 = the minimum distance between the pedestrian and the *acute warning area* in front of the car (`min_dist_awa`)

Note that all objective functions are considered equally important. We refer to the result from optimizing the three objective functions as a *critical scenario*.

### Test input
To test the pedestrian detection system, a simple scene has been implemented in Pro-SiVIC. The scene enables a replication of the solution presented by Ben Abdessalem et al. (2016) implemented in PreScan. The scene contains a car driving on a straight road and a pedestrian crossing the street from the right. There are no objects along the road, and the driving conditions are normal. Test scenarios are created for this scene by setting five independent test parameters within fixed ranges, i.e., the test input:

1. the x coordinate of the pedestrian (`ped_x`) [
1. the y coordinate of the pedestrian (`ped_y`)
1. the orientation of the pedestrian (`ped_orient`)
1. the speed of the pedestrian (`ped_speed`)
1. the speed of the car (`car_speed`)

### Source code structure
The main files in the root folder are:
- run_NSGAII.m: Main file for running NSGA-II to search for test input representing critical scenarios.
- mock_pedestrian_detection_system.slx: Simulink implementation with a mocked PDS. Communicates with Pro-SiVIC using DDS.
- run_from_file.m: Read a set of test scenarios from a csv-file and run them in Pro-SiVIC.
- run_from_file_theory.m: Read a set of test scenarios from a csv-file and calculate what the .

The four subfolders contain the following:

- `genetic_algo`: A refactored version of the original algorithm NSGA-II tailored for generation of test cases representing critical test scenarios. NSGA-II was originally developed by the Kanpur Genetic Algorithm Labarotary http://www.iitk.ac.in/kangal/ We hope that the refactored version will be easier to understand for non-experts.
- `scripts`: Two Pro-SiVIC scripts. First, the Pro-SiVIC scene that replicates the PreScan scene by Ben Abdessalem et al. (2016). Second, a script to turn on shadows for each body part of the Pro-SiVIC pedestrian.
- `utils`: Three utility functions called by the main MATLAB scripts.

Workaround to start DCPSInforRepo: `DCPSInfoRepo -o f:/temp/repo.ior -ORBListenEndpoints iiop://:4242`

## scripts
Supporting scripts to reproduce our results. Instructions will follow when the paper manuscript has been finished.

## example_prosivic_matlab
The code can be used to get started with DDS communication between Pro-SiVIC and MATLAB. The code is provided as is, but should be fairly straightforward even without documentation beyond code comments.

## example_prosivic_simulink
The code can be used to get started with DDS communication between Pro-SiVIC and Simulink. The code is provided as is, but should be fairly straightforward even without documentation beyond code comments.

## References
- Ben Abdessalem, R., Nejati, S., Briand, L.C. and Stifter, T. Testing advanced driver assistance systems using multi-objective search and neural networks. In Proceedings of the 31st IEEE/ACM International Conference on Automated Software Engineering (pp. 63-74)., 2016.
