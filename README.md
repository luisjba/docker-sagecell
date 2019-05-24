This is a dockerized SageMathCell - a Sage computation web service. Usign the oficial sage image sagemath/sagemath and installed the latest sagecell from https://github.com/sagemath/sagecell

# Docker SageMathCell (SageCell)

### Installation

    docker pull luisjba/sagecell

or simply continue to the next step.

### Running SagegCell

To run SageCell:

    docker run -d -p 8888:8888 luisjba/sagecell

Then you can open the address http://localhost:8888 in your browser and start
using the sagecell after accepting the Term of Service (tos) for SageMathCell.

## Customizing SageCell with environment varaibles

You can customize your SageCell sending the desired  environment variables
available to the container.This variables are passed to the entry point and
perform the updates in the config.py file of SageCell.

### SageCell config variables

- SAGECELL_KERNEL_DIR: This is the directory in which sagecell store the generated
kernel files with json format inside each file. Default value = /home/sage/sagecellkernels.
- SAGECELL_PROVIDER_SETTINGS_MAX_KERNELS: The maximum number of alive kernels.
Default value = 10
- SAGECELL_PROVIDER_SETTINGS_PRE_FROKED: The keys to resource_limits can be any
available resources
for the resource module. See http://docs.python.org/library/resource.html
for more information (section 35.13.1)
RLIMIT_AS is more of a suggestion than a hard limit in Mac OS X
Also, Sage may allocate huge AS, making this limit pointless:
https://groups.google.com/d/topic/sage-devel/1MM7UPcrW18/discussion .
Default value = 1
- SAGECELL_PROVIDER_SETTINGS_PRE_FROKED_LIMIT_CPU: The CPU time in seconds.
Default value = 120

### SageCell service variables

- SAGECELL_PORT: The port to run the sagecell in the Tornado Server.
Default value = 8888

## Customizing container configuration

In this example you can configure the CPU time passing the variable
SAGECELL_PROVIDER_SETTINGS_PRE_FROKED_LIMIT_CPU
with your custom value, in this case 5 minutes  (60 * 5)

    docker run -e SAGECELL_PROVIDER_SETTINGS_PRE_FROKED_LIMIT_CPU="60 * 5" -d -p 8888:8888 luisjba/sagecell

# Run SageMath as application

SageCell contains SageMath installed and you can access it as an application
in the terminal atacching the ssh session by
the docker exec utility running the following command.

    docker exec -it <instance_name> bash -c "sage"

If you want to set you custom instance name with the --name option and then run
the sage application calling the instance by the custom name.

### run sage application and se sagecell as custom name

Run the SagegCell with sagcell name

    docker run --name sagecell -d -p 8888:8888 luisjba/sagecell

Connecting to the ssh session in the docker container sagecell and run the sage application.

    docker exec -it sagecell bash -c "sage"

Other software included in the image can be run similary:

    docker exec -it sagecell bash -c "sage gap"

    docker exec -it sagecell bash -c "sage gp"        # PARI/GP

    docker exec -it sagecell bash -c "sage maxima"

    docker exec -it sagecell bash -c "sage R"

    docker exec -it sagecell bash -c "sage singular"

## run the SageMath notebook

You can run the sagecell and the notebook in the same container but you
must take care when setting custom ports . Sagecell by default runs on the port 8888
and notebook in 8080 and need to be exposed when run the container.
This is done in two steps, forts run the container and then execute the notebook application.

1 - Run the the instance with sagecell name and expose the ports 8888 for sagecell
and 8080 for the notebook

    docker run --name sagecell -d -p 8888:8888 -p 8080:8080 luisjba/sagecell


2 - Start the notebook with the sage application

    docker exec -it sagecell bash -c "sage -notebook"

You can pass a custom port for the notebook passing the option --port

    docker exec -it sagecell bash -c "sage -notebook --port=8080"

For better configuration to allow connections to the notebook through the Docker network, you can run as follow:

    docker exec -it sagecell bash -c "sage -notebook=jupyter --no-browser --ip='*' --port=8080"    
