% This script demonstrates how multi-objective optimization can be used for
% generation of critical scenarios in simulation-based ADAS testing. The script
% implements an evolutionary algorithm, NSGA-II, to find the optimal
% solution for multiple objectives, i.e., the Pareto front for the objectives.
%
% The original algorithm NSGA-II was developed by the Kanpur Genetic
% Algorithm Labarotary http://www.iitk.ac.in/kangal/
%
%  Copyright (c) 2009, Aravind Seshadri
%  Copyright (c) 2015-2019, Raja Ben Abdessalem
%  Copyright (c) 2019, Markus Borg
%  All rights reserved.
%
%  Redistribution and use in source and binary forms, with or without
%  modification, are permitted provided that the following conditions are
%  met:
%
%     * Redistributions of source code must retain the above copyright
%       notice, this list of conditions and the following disclaimer.
%     * Redistributions in binary form must reproduce the above copyright
%       notice, this list of conditions and the following disclaimer in
%       the documentation and/or other materials provided with the distribution
%
%  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
%  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
%  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
%  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
%  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
%  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
%  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
%  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
%  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
%  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
%  POSSIBILITY OF SUCH DAMAGE.

nbr_runs = 1; % number of NSGAII runs to perform
for loops = 1:nbr_runs
    try
        
        %%%%%%%%%%%%%%%%%%%%%%
        %%% INITIALIZATION %%%
        %%%%%%%%%%%%%%%%%%%%%%

        mfilepath = fileparts(which('run_NSGAII.m'));
        addpath(fullfile(mfilepath,'/Functions'));
        addpath(fullfile(mfilepath,'/GA'));
        load_system(fullfile(mfilepath,'/pedestrian_detection_system.slx'));     
        short_time_format = 'yyyymmdd_HHMMss';
        long_time_format = 'yyyymmdd_HHMMss_FFF';
        
        sim_time = 10;
        Fn_MiLTester_SetSimulationTime(sim_time);
        start_time = now;
        nbr_simulation_calls = 0;
           
        population_size = 10; 
        nbr_obj_funcs = 3;
        nbr_inputs = 5;
        chromosome = NaN(size(population_size, nbr_inputs));
                
        % The center of the Mini Cooper in the Pro-SiVIC scene is (282.70, 301.75).
        % Note that this corresponds to a chassis at x=284.0 in Pro-SiVIC, as the
        % rear axis is the primary point for positioning. To compensate for this,
        % we subtract 1.3 m from xCar in the Simulink model.
        car_x0 = 282.70;
        car_y0 = 301.75;
        
        % Input ranges for the random initialization:
        % [ped_x; ped_y; ped_orient; ped_speed; car_speed]
        min_ranges = [x0C - 85; y0C + 2; -140; 1; 1 * 3.6]; 
        max_ranges = [x0C - 20; y0C + 15; -20; 5; 25 * 3.6];        
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% 1. NSGAII: Randomly create an initial population. %%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  
        time_now = datestr(now, short_time_format);
        fprintf('%s - Creating initiatial population of size %s\n', time_now, int2str(population_size));
        
        for i = 1:population_size
            
            for j = 1:nbr_inputs
                % randomly create chromosomes
                chromosome(i,j) = (min_ranges(j) + (max_ranges(j) - min_ranges(j)) * rand(1));
            end
            
            % store input values from chromosome in variables used later
            ped_x = chromosome(i,1);
            ped_y = chromosome(i,2);
            ped_orient = chromosome(i,3);
            ped_speed = chromosome(i,4);
            car_speed = chromosome(i,5);
            
            
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%% 2. Pro-SiVIC: Run a simulation for the initial population. %%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            run_single_scenario
            nbr_simulation_calls = nbr_simulation_calls + 1;
            
            % check if the simulation resulted in a pedestrian detection
            detection = 0;
            detection_vector = sim_out.Detection.signals.values;
            for j = 1:length(detection_vector)
                if detection_vector(j) > 0
                    detection = 1;
                    break
                end
            end      
            chromosome(i, nbr_inputs + 1) = detection; % store the result
            
            % check if the simulation resulted in a collision with the pedestrian
            collision = 0;
            collision_vector = sim_out.isCollision.signals.values;
            for j = 1 : length(collision_vector)
                if collision_vector(j) > 0
                    collision = 1;
                    break
                end
            end
            chromosome(i, nbr_inputs + 2) = collision;
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%% 3. NSGAII: Evaluate the objective functions for the initial population. %%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % calculate the objective functions
            min_dist = 100; % minimum distance between car and pedestrian
            min_ttc = 4; % minimum time to collision according to PDS
            min_dist_awa = 50; % minimum distance to acute warning area
            [min_dist, min_ttc, min_dist_awa] = calc_obj_funcs(sim_out, ped_orient);

            chromosome(i, nbr_inputs + 3) = min_dist;     
            chromosome(i,nbr_inputs+4) = min_ttc;
            chromosome(i,nbr_inputs+5) = min_dist_awa;
            
        end % the initial population has been evaluated
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% 4. NSGAII: Sort the initial population. %%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        chromosome = non_domination_sort_mod(chromosome, nbr_obj_funcs, nbr_inputs + 2);
        
        time_now = datestr(now, long_time_format);
        filename = strcat('output/results_NSGAII_', time_now, '.txt');      
        fid = fopen(filename, 'w');
        
        fprintf(fid, '\nInitial chromosome:\n');
        fprintf(fid, '%s  %s  %s  %s  %s  %s  %s  %s  %s  %s  %s  %s\n',['ped_x' '       ' 'ped_y' '        ' 'ped_orient' '       ' 'ped_speed' '      ' 'car_speed' '     ' 'detection' '    ' 'collision' '   ' 'of1' '    ' 'of2' '   ' 'of3'  '     ' 'rank' '    ' 'crowding_dist' ]);
        fprintf(fid, '\n');
        clear tmp_results
        tmp_results(:, 1:nbr_obj_funcs + nbr_inputs + 4) = chromosome;
        clear tmp_results_2;
        for i=1:size(tmp_results,1)
            tmp_results_2(:,i)=tmp_results(i,:);
        end
        fprintf(fid, '%.6f  %.6f  %.6f  %.6f  %.6f  %d  %d  %.6f  %.6f %.6f %d %.6f\n', tmp_results_2);
        
        cumulative_execution_time = toc
        nbr_generations = 0;
        
        while cumulative_execution_time < 9000 %150min
            cumulative_execution_time = toc
            fprintf(fid, 'SimTimeUntilNow %.3f \n', cumulative_execution_time);
            nbr_generations = nbr_generations + 1;
            fprintf(fid, '\n Total number of times we call the sim until now = %d \n', nbr_simulation_calls);
            fprintf(fid, '%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% \n');
            fprintf(fid, 'Generation Number = %d \n', nbr_generations);
                    
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%% 5. NSGAII: Select mates using tournament selection %%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % Use tournament selection to find to individuals in the mating pool
            pool_size = round(population_size / 2);
            tournament_size = 2;
            parent_chromosome = tournament_selection(chromosome, pool_size, tournament_size);
            
            nbr_mutations = 20;
            
            [N, m] = size(parent_chromosome);
            clear m
            counter = 1; % this counter puts children in the right index          
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%% 6. NSGAII: Perform crossover %%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            for i = 1:N
                % With 90 % probability perform crossover
                if rand(1) < 0.9
                    % Initialize the children to be null vector.
                    child_1 = [];
                    child_2 = [];
                    % Select the first parent
                    parent_1 = round(N * rand(1));
                    if parent_1 < 1
                        parent_1 = 1;
                    end
                    % Select the second parent
                    parent_2 = round(N * rand(1));
                    if parent_2 < 1
                        parent_2 = 1;
                    end
                    % Make sure both the parents are not the same.
                    while isequal(parent_chromosome(parent_1, :), parent_chromosome(parent_2, :))
                        parent_2 = round(N*rand(1));
                        if parent_2 < 1
                            parent_2 = 1;
                        end
                    end
                    
                    % Get the chromosome information for each randomly selected parent
                    parent_1 = parent_chromosome(parent_1, :);
                    parent_2 = parent_chromosome(parent_2, :);
                    
                    % Perform crossover for each decision variable in the chromosome.
                    for j = 1:nbr_inputs
                        % SBX (Simulated Binary Crossover).
                        u(j) = rand(1);
                        if u(j) <= 0.5
                            bq(j) = (2 * u(j))^(1 / (nbr_mutations + 1));
                        else
                            bq(j) = (1 / (2 * (1 - u(j))))^(1 / (nbr_mutations + 1));
                        end
                        % Generate the jth element of first child
                        child_1(j) = ...
                            0.5 * (((1 + bq(j)) * parent_1(j)) + (1 - bq(j)) * parent_2(j));
                        % Generate the jth element of second child
                        child_2(j) = ...
                            0.5 * (((1 - bq(j)) * parent_1(j)) + (1 + bq(j)) * parent_2(j));
                        % Make sure that the generated element is within the specified
                        % decision space else set it to the appropriate extrema.
                        if child_1(j) > max_ranges(j)
                            child_1(j) = max_ranges(j);
                        elseif child_1(j) < min_ranges(j)
                            child_1(j) = min_ranges(j);
                        end
                        if child_2(j) > max_ranges(j)
                            child_2(j) = max_ranges(j);
                        elseif child_2(j) < min_ranges(j)
                            child_2(j) = min_ranges(j);
                        end
                    end
                    
                else
                    % Initialize the children as null vectors
                    child_1 = [];
                    child_2 = [];
                    % Select the first parent
                    parent_1 = round(N*rand(1));
                    if parent_1 < 1
                        parent_1 = 1;
                    end
                    % Select the second parent
                    parent_2 = round(N*rand(1));
                    if parent_2 < 1
                        parent_2 = 1;
                    end
                    % Make sure both the parents are not the same.
                    while isequal(parent_chromosome(parent_1, :),parent_chromosome(parent_2, :))
                        parent_2 = round(N*rand(1));
                        if parent_2 < 1
                            parent_2 = 1;
                        end
                    end
                    % Get the chromosome information for each randomly selected parent
                    parent_1 = parent_chromosome(parent_1, :);
                    parent_2 = parent_chromosome(parent_2, :);
                    for j = 1:nbr_inputs
                        child_1(j) = parent_1(j);
                        
                        child_2(j) = parent_2(j);
                    end                 
                end
                
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %%% 7. NSGAII: Insert mutations %%%
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
                if rand(1) < 0.5
                    %do mutation
                    delta=[2 2 10 1 1.4];
                    for j = 1 : nbr_inputs
                        
                        child_1(j) = child_1(j) + Fn_MiLTester_My_Normal_Rnd(0, delta(j));
                        % Make sure that the generated element is within the decision space.
                        if child_1(j) > max_ranges(j)
                            child_1(j) = max_ranges(j);
                        elseif child_1(j) < min_ranges(j)
                            child_1(j) = min_ranges(j);
                        end
                        
                        child_2(j) = child_2(j) + Fn_MiLTester_My_Normal_Rnd(0, delta(j));
                        % Make sure that the generated element is within the decision space.
                        if child_2(j) > max_ranges(j)
                            child_2(j) = max_ranges(j);
                        elseif child_2(j) < min_ranges(j)
                            child_2(j) = min_ranges(j);
                        end
                    end
                else
                    %copy
                    for j = 1:nbr_inputs
                        child_1(j) = child_1(j);
                        
                        child_2(j) = child_2(j);
                    end
                end
                
                
                
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %%% 8. Pro-SiVIC: Run a simulation for child 1. %%%
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                
                % intitilize a scenario corresponding to child 1
                ped_x = child_1(1);
                ped_y = child_1(2);
                ped_orient = child_1(3);
                ped_speed = child_1(4);
                car_speed = child_1(5);
                
                run_single_scenario
                nbr_simulation_calls = nbr_simulation_calls + 1;
                          
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %%% 9. NSGAII: Evaluate the objective functions for child 1. %%%
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                
                % check if the simulation resulted in a pedestrian detection
                detection = 0;
                detection_vector = sim_out.Detection.signals.values;
                for j = 1:length(detection_vector)
                    if detection_vector(j) > 0
                        detection = 1;
                        break
                    end
                end                
                child_1(6) = detection; % store the result
                
                % check if the simulation resulted in a collision with the pedestrian
                collision = 0;
                collision_vector = sim_out.isCollision.signals.values;
                for j = 1 : length(collision_vector)
                    if collision_vector(j) > 0
                        collision = 1;
                        break
                    end
                end
                child_1(:, nbr_inputs + 2) = collision; % store the result
                
                % calculate the objective functions
                min_dist = 100; % minimum distance between car and pedestrian
                min_ttc = 4; % minimum time to collision according to PDS
                min_dist_awa = 50; % minimum distance to acute warning area
                [min_dist, min_ttc, min_dist_awa] = calc_obj_funcs(sim_out, ped_orient);

                % Storing results for child_1 as follows:
                % child_1(:,nbr_inputs + 1: nbr_obj_funcs + nbr_inputs) = evaluate_objective(child_1, nbr_obj_funcs, nbr_inputs);
                
                child_1(:, nbr_inputs + 3) = min_dist;
                child_1(:, nbr_inputs + 4) = min_ttc;
                child_1(:, nbr_inputs + 5) = min_dist_awa;
                                              
                           
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %%% 10. Pro-SiVIC: Run a simulation for child 2. %%%
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                
                % intitilize a scenario corresponding to child 2
                ped_x = child_2(1);
                ped_y = child_2(2);
                ped_orient = child_2(3);
                ped_speed = child_2(4);
                car_speed = child_2(5);
                
                run_single_scenario
                nbr_simulation_calls = nbr_simulation_calls + 1;

                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %%% 11. NSGAII: Evaluate the objective functions for child 2. %%%
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                
                % check if the simulation resulted in a pedestrian detection
                detection = 0;
                detection_vector = sim_out.Detection.signals.values;
                for j = 1:length(detection_vector)
                    if detection_vector(j) > 0
                        detection = 1;
                        break
                    end
                end                             
                child_2(6) = detection; % store the result
                
                % check if the simulation resulted in a collision with the pedestrian
                collision = 0;
                collision_vector = sim_out.isCollision.signals.values;
                for j = 1 : length(collision_vector)
                    if collision_vector(j) > 0
                        collision = 1;
                        break
                    end
                end
                child_2(:,nbr_inputs + 2) = collision;
                
                % calculate the objective functions
                min_dist = 100; % minimum distance between car and pedestrian
                min_ttc = 4; % minimum time to collision according to PDS
                min_dist_awa = 50; % minimum distance to acute warning area
                [min_dist, min_ttc, min_dist_awa] = calc_obj_funcs(sim_out, ped_orient);
                             
                % Storing results for child_2 as follows:
                % child_2(:,nbr_inputs + 1: nbr_obj_funcs + nbr_inputs) = evaluate_objective(child_2, nbr_obj_funcs, nbr_inputs);
 
                child_2(:, nbr_inputs + 3) = min_dist;
                child_2(:, nbr_inputs + 4) = min_ttc;           
                child_2(:, nbr_inputs+5) = min_dist_awa;             
                
                % Keep proper count and appropriately fill the child variable with all
                % the generated children for the particular generation.
                
                child(counter, :) = child_1;
                child(counter+1, :) = child_2;
                counter = counter + 2;
                
            end % end of crossover
            
            offspring_chromosome = child;
            
            [main_pop, temp] = size(chromosome);
            [offspring_pop, temp] = size(offspring_chromosome);
            
            % temp is a dummy variable.
            clear temp
            
            % intermediate_chromosome is a concatenation of current population and the offspring population.
            intermediate_chromosome(1:main_pop, :) = chromosome;
            intermediate_chromosome(main_pop + 1 : main_pop + offspring_pop,1 : nbr_obj_funcs + nbr_inputs + 2) = ...
                offspring_chromosome;
            
            intermediate_chromosome = ...
                non_domination_sort_mod(intermediate_chromosome, nbr_obj_funcs, nbr_inputs + 2);
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%% 12. NSGAII: Select the best individuals based on elitism and crowding distance. %%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                
            fprintf(fid, 'Intermediate_Chromosome after sorting\n');
            clear InB
            clear InC
            
            InB(:, 1:nbr_obj_funcs + nbr_inputs + 4) = intermediate_chromosome;
            clear a;
            for i = 1:size(InB,1)
                tmp_results_2(:, i)=InB(i, :);
            end
            fprintf(fid, '%.6f  %.6f  %.6f  %.6f  %.6f  %d  %d  %.6f  %.6f %.6f %d %.6f\n', tmp_results_2);
            
            cumulative_execution_time = toc
            fprintf(fid, 'Cumulative execution time: %.3f \n', cumulative_execution_time);
            
            chromosome = replace_chromosome(intermediate_chromosome, nbr_obj_funcs, nbr_inputs+2, population_size);
            
            fprintf(fid, 'Selected chromosome\n');
            clear InC
            InC(:, 1:nbr_obj_funcs + nbr_inputs + 4) = chromosome;
            clear a;
            for i = 1:size(InC, 1)
                tmp_results_2(:, i) = InC(i, :);
            end
            
            fprintf(fid, '%.6f  %.6f  %.6f  %.6f  %.6f  %d  %d  %.6f  %.6f %.6f %d %.6f\n', tmp_results_2);
            
        end % end while X < maximum simulation time
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% Print NSGAII results %%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        fprintf(fid, '\n solution \n');
        clear a;
        for i = 1:size(chromosome, 1)
            tmp_results_2(:, i) = chromosome(i, :);
        end
        fprintf(fid, '%.6f  %.6f  %.6f  %.6f  %.6f  %d  %d  %.6f  %.6f %.6f %d %.6f\n', tmp_results_2);
        
        totSimTime=toc
        fprintf(fid, 'totSimTime %.3f \n', totSimTime);
        fprintf(fid, '\n Total number of Pro-SiVIC simulations within the time budget = %d\n', nbr_simulation_calls);
               
        display(strcat('Total execution time = ',num2str(round((now - start_time) * (24 * 60))), 'min'));
        fclose(fid);
        
    catch exc
        disp(getReport(exc));
        disp('Error in model test run!');
    end
    
end