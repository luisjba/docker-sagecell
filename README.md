# Docker SageMathCell (SageCell)

This is a dockerized SageMathCell - a Sage computation web service. 
This image was builded using the oficial docker sagemath image 
[sagemath/sagemath](https://hub.docker.com/r/sagemath/sagemath) and 
installed the latest [sagecell](https://github.com/sagemath/sagecell) and providing 
customization to the sagecell that includes:
- Install extra libraries into sage with pip.
- Install custom libraries into sage mounting a volume.

### Installation

    docker pull luisjba/sagecell

or simply continue to the next step.

### Running SageCell

To run SageCell:

    docker run -d -p 8888:8888 luisjba/sagecell

Then you can open the address http://localhost:8888 in your browser and start
using the sagecell to execute sage code by default or other supported languages 
(Gap, GP, HTML, Macualay2, Maxima, Octave, Python, R and Singular) after accepting 
the Term of Service (tos) for SageMathCell. 
You can use the sagecell for [embedding](https://github.com/sagemath/sagecell/blob/master/doc/embedding.rst) 
Sage computations into any webpage or comunicate with the kernel (the  kernel is an IPython kernel)
using the provided protocols:

- HTTP
- WebSockets  
- SockJS

For detailed information read more about [kernel comunicate](https://github.com/sagemath/sagecell/blob/master/doc/messages.md)  
in the oficial source code

## Customizing SageCell with environment variables

You can customize your SageCell sending the desired  environment variables
available for the container. This variables are passed to the entry point in
the docker container to perform the configuration. Customizing this variables 
you could:  

- Change the ports to run for SSH, SageCell and Jupiter Notebook
- Set the configuration to the config.py file for SageCell
- indicate extra libraries to install into sage via pip 
- install custom libraries into sage in a mounted volume.

### Configure service ports

You can customize the ports for SageCell, SSH Server and Jupiter Notebook 
seting the value to the next available variables:

- **PORT**: By default is 8888 and is where SageCell runs.
- **SSH_PORT**: By default is 22 and used for SSH Server.
- **JN_PORT**: By default is 8080 intended for run the Sage Jupyter Notebook.

### Configure SageCell

This configuration is persisted in the **config.py** file and reconstructed 
every time that the docker container runs and the container entry point is 
executed passed the default commands and environment variables. 

The config.py file is a Python file and used by SageCell to load the configuration 
on start up. Please follow the Python syntax when modify this group of variables 
and set your custom values. For example, a boolean value in Python is **`True`** and **`False`**.
For variables that use numeric values you can set numeric operations ( +, -, *, /, **, sqrt, etc) like  **`60 * 60`** when 
accepts milliseconds for better understand the conversion to minutes or other time scales.


- **SAGECELL_REQUIRE_TOS**: Boolean with default value `True`. 
When `True` Require the user to accept terms of service before evaluation.
- **SAGECELL_KERNEL_DIR**: String with default value `/home/sage/sagecellkernels`. 
This is the directory in which SageCell stores JSON formatted files for the generated kernels.
- **SAGECELL_BEAT_INTERVAL**: Numeric with default value `0.5`. 
Parameters for heartbeat channels checking whether a given kernel is alive. 
- **SAGECELL_FIRST_BEAT**: Numeric with default value `1.0`. 
Setting first_beat lower than 1.0 may cause JavaScript errors.
- **SAGECELL_MAX_TIMEOUT**: Numeric with default value `60 * 90`. 
Allowed idling between interactions with a kernel
- **SAGECELL_MAX_LIFESPAN**: Numeric with default value `60 * 119`. 
Even an actively used kernel will be killed after this time
- **SAGECELL_PROVIDER_SETTINGS_MAX_KERNELS**: Numeric with default value `10`. 
The maximum number of alive kernels.
- **SAGECELL_PROVIDER_SETTINGS_PRE_FROKED**: Numeric with default value `1`. 
The keys to resource_limits can be any available resources
for the [resource module more information in section section 35.13.1](http://docs.python.org/library/resource.html ). 
See RLIMIT_AS is more of a suggestion than a hard limit in Mac OS X
Also, Sage may allocate huge AS, making this limit pointless 
([se discussion](https://groups.google.com/d/topic/sage-devel/1MM7UPcrW18/discussion)).
- **SAGECELL_PROVIDER_SETTINGS_PRE_FROKED_LIMIT_CPU**: Numeric with default value `120`. 
The CPU time in seconds.

### Install package into sage via pip

We can install our custom packages into sage, setting the package name or more (space separated) into 
the var `SAGE_INSTALL_CUSTOM_LIBS`, then the entry point executed by the container will red this packages
and install it via pip. For example if you want to install Pythonic XML processing library, the package name
in pip is lxml and you have to set into `SAGE_INSTALL_CUSTOM_LIBS="lxml"` to indicate the container to install
it by sage via pip.

    docker run --name sagecell -e SAGE_INSTALL_CUSTOM_LIBS="lxml" -d -p 8888:8888 luisjba/sagecell   

### Install custom package from docker volume

Another way to install a custom package into sage when this package is not accessible in the pip 
repository is to copy in a directory into the docker host and mount it as volume with the path `/home/sage/libs`
in the container side.

    docker run --name sagecell -v /home/user/my/customs/lib:/home/sage/libs  -d -p 8888:8888 luisjba/sagecell
    
When the container is stating up, the entry point script check in the `/home/sage/libs` directory and crete symbolics links
into the sage python library directory for every directory found. You can change the directory form where 
the entry point will find libraries setting the new directory in `SAGE_LIBS_DIR=/home/sage/mycustomdirlib`
with your desired directory value. Don't forget to mount your lib volume pointing to this new directory.

    docker run --name sagecell -e SAGE_LIBS_DIR=/home/sage/mycustomdirlib -v /home/user/my/customs/lib:/home/sage/mycustomdirlib  -d -p 8888:8888 luisjba/sagecell


# Run SageCell with SageMath as application

This SageCell docker image contains [SageMath](http://www.sagemath.org "SageMath is a free open-source mathematics software system licensed under the GPL")
installed and you can access it as an application into your terminal.
 
To explain this features, we will run a named docker container passing `--name sagecell` option to docker for 
set the name **sagecel** to the container.

    docker run --name sagecell -d -p 8888:8888 luisjba/sagecell

When a SageCell container is running you can run *sage* by attaching the ssh session using
the docker exec utility an execute sage.

    docker exec -it <instance_name> bash -c "sage"

As our instance has the *sagecell* name, we must call the above command as follows
    
    docker exec -it sagecell bash -c "sage"

If you want to set another name to the instance and see the instance name, consult the official
doc reference of the command [docker ps](https://docs.docker.com/engine/reference/commandline/ps/).


Other software included in the image can be executed similarly:

    docker exec -it sagecell bash -c "sage gap"

    docker exec -it sagecell bash -c "sage gp"        # PARI/GP

    docker exec -it sagecell bash -c "sage maxima"

    docker exec -it sagecell bash -c "sage R"

    docker exec -it sagecell bash -c "sage singular"

# Run SageCell with Jupyter Notebook

You can run the SageCell and the notebook in the same container but you
must take care when setting custom ports . SageCell by default runs on the port 8888
and Jupyter Notebook in 8080. You must expose the ports when run the container.
This is done in two steps:

1. Run the a named container with *sagecell* as name and expose the ports 8888 for SageCell
and 8080 for Jupyter Notebook.

        docker run --name sagecell -d -p 8888:8888 -p 8080:8080 luisjba/sagecell
        
2. Start the notebook with the sage application

        docker exec -it sagecell bash -c "sage -notebook"

You can set a custom port for the notebook passing the option --port

    docker exec -it sagecell bash -c "sage -notebook --port=8080"

For better configuration to allow connections to the notebook through the Docker network, you can run as follow:

    docker exec -it sagecell bash -c "sage -notebook=jupyter --no-browser --ip='*' --port=8080"
    
If you set a different port than default (8080) for Jupyter Notebook, be sure to connect and expose 
them in the `-p [host_port]:[container_port]` option when running the container.

## Donate

If this project was usefull for you and you want to thanks me you can buy me a cup coffe.

[![paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=GVCZHZPGL7E2U&source=url)

![Donate QR Code ](images/Donate_QR_Code.png "Buy me a cup of Coffe :)")
