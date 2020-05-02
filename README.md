# GenderedDescriptions
Extract gendered descriptions of body parts from text

In order to run this, you need Python and spaCy installed on your machine (in addition to R) 

I installed them as follows:
1. Download Anaconda and step through the installer as usual
<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;https://www.anaconda.com/distribution/#download-section
2. Search for Anaconda Prompt in the start menu, and right click and select Run as Administrator
3. Paste the following prompts in and hit enter after each. If any y/n prompts pop up, pick y.
<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;conda config --add channels conda-forge
<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;conda install spacy
<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;python -m spacy download en
