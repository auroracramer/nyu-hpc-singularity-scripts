Image creation info
-------------------

To create the image, the Dockerfile from hear-eval-kit was modified to:
    1) remove unnecessary Google Cloud stuff
    2) install things installed by the Ubuntu .sif images in /scratch/work/public/singularity
    3) remove Python environment setup since we're putting it in an ext3

Using a local Docker installation (on a laptop), the Docker image was built,
and a singularity image was bootstrapped from the local docker image server. The
resulting .sif file was then uploaded here.

Commands:

```
sudo docker build -t marl/eleval - < embodied-listening-eval.Dockerfile
sudo docker tag marl/eleval localhost:5000/marl/eleval
sudo docker push localhost:5000/marl/eleval
sudo SINGULARITY_NOHTTPS=1 singularity build embodied-listening-eval.sif embodied-listening-eval.def
scp embodied-listening-eval.sif jtc440@gdtn:/scratch/jtc440/overlay/sif/
```
