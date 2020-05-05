# GenderedDescriptions
<h2>Running the code</h2>
This code as uploaded will identify body parts and associated adjectives in Jane Austin's Emma.
  
In order to run this, you need Python and spaCy installed on your machine (in addition to R).
  
I installed them as follows:
1. Download Anaconda and step through the installer as usual
<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;https://www.anaconda.com/distribution/#download-section
2. Search for Anaconda Prompt in the start menu, and right click and select Run as Administrator
3. Paste the following prompts in and hit enter after each. If any y/n prompts pop up, pick y.
<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;conda config --add channels conda-forge
<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;conda install spacy
<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;python -m spacy download en

<h2>A note on the results</h2>
For a given body part (or bodypart+adjective pair), I calculate the gender skew as follows

<img src="https://latex.codecogs.com/gif.latex?pctF&space;=&space;\frac{count\:of\:this\:bodypart}{count\:of\:all\:female\:body\:parts}\\\\\\&space;pctM&space;=&space;\frac{count\:of\:this\:bodypart}{count\:of\:all\:male\:body\:parts}\\\\\\&space;if\:pctM>pctF,\:skew=\frac{pctM}{pctF}\:\:else\:skew&space;=&space;\frac{-pctF}{pctM}" title="pctF = \frac{count\:of\:this\:bodypart}{count\:of\:all\:female\:body\:parts}\\\\\\ pctM = \frac{count\:of\:this\:bodypart}{count\:of\:all\:male\:body\:parts}\\\\\\ if\:pctM>pctF,\:skew=\frac{pctM}{pctF}\:\:else\:skew = \frac{-pctF}{pctM}" />
