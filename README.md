# Arxane
Keeping up with new arxiv papers is difficult. Arxane is an extensible emacs application for making this easier.

# TODOS
What would be really nice is a kind of YES/NO tinder-like add interface wherein the o.g. list interface is sort of an outer layer. I'm imagining like a screen that looks like

``` text
arXiv:2603.19247v1 Announce Type: new 
Abstract: Large Language Models (LLMs) are increasingly integrated into high-stakes applications, making robust safety guarantees a central practical and commercial concern. Existing safety evaluations predominantly rely on fixed collections of harmful prompts, implicitly assuming non-adaptive adversaries and thereby overlooking realistic attack scenarios in which inputs are iteratively refined to evade safeguards. In this work, we examine the vulnerability of contemporary language models to automated, adversarial prompt refinement. We repurpose black-box prompt optimization techniques, originally designed to improve performance on benign tasks, to systematically search for safety failures. Using DSPy, we apply three such optimizers to prompts drawn from HarmfulQA and JailbreakBench, explicitly optimizing toward a continuous danger score in the range 0 to 1 provided by an independent evaluator model (GPT-5.1). Our results demonstrate a substantial reduction in effective safety safeguards, with the effects being especially pronounced for open-source small language models. For example, the average danger score of Qwen 3 8B increases from 0.09 in its baseline setting to 0.79 after optimization. These findings suggest that static benchmarks may underestimate residual risk, indicating that automated, adaptive red-teaming is a necessary component of robust safety evaluation.
```


- [ ] If the arxane-summary exists delete it first
- [ ] Need some way of marking useful items
- [ ] Figure out integration. Probably with org or something.
- [ ] Clean up code / figure out standardization
