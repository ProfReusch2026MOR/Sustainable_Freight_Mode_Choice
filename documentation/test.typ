#let c = (yellow, red, green, blue).map(x => x.lighten(50%))
#figure(
  caption: "Training",
  diagram(
    node-stroke: 1pt,
    node-corner-radius: 3pt,
    spacing: 40pt,
    node((0,0), [Base Model], name: <1>, width: 90pt, height: 50pt, shape: "rect", fill:c.at(1)),
    edge("-straight"),
    node((1,0), text("GRPO\nwith verifiable\nrewards"), name:<2>, width: 90pt, height: 50pt, shape: "rect", fill:c.at(3)),
    node((1,-1), [Code-Dataset], name: <3>, width: 90pt, height: 50pt, shape: "rect",fill:c.at(0)),
    node((2, 0), [Refined Model], name: <4>, width: 90pt, height: 50pt, shape: "rect",fill:c.at(1)),
    edge(<3>, "-straight", <2>),
    edge(<2>, "-straight", <4>)
  )
)

#show stack: set align(left)

#figure(
  caption: "An example of a LeetCode problem",
  stack(
    panel("Problem Statement", [Given an array of integers nums and an integer target, return indices of the two numbers such that they add up to target. You may assume that each input would have exactly one solution, and you may not use the same element twice. You can return the answer in any order.], c.at(0)),
    panel("Examples",[Example 1: \ Input: nums = [2,7,11,15] \ target = 9 \ Output: [0,1] \ Explanation: Because nums[0] + nums[1] == 9, we return [0, 1].
  
    Example 2: \ Input: nums = [3,2,4] \ target = 6 \ Output: [1,2]]
    , c.at(0)),
    panel("Constraints",[2 <= nums.length <= 104 \ -109 <= nums[i] <= 109 \ -109 <= target <= 109 \ Only one valid answer exists.], c.at(0)),
    panel("Starter Code", [```python
    class Solution: 
      def twoSum(self, nums: List[int], target: int) -> List[int]:```], c.at(0))
  )
)

Top-down tokenizers are rule-based, i.e. they split up raw text based on predefined rules that are based on regular expressions. @nltk shows 
a basic regular expression that can be used to tokenize English text with the Natural Language Toolkit (NLTK) @Bird2009. The main disatvantage of this tokenization method is that even for languages where words are seperated by whitespaces like english, german and french, every language needs its own tokenizer. Each language has different sub-word tokens for verb endings and unique ambiguities such as the apostrophe ("don't", "Max' Auto", "aujourd'hui").

#figure(
  caption: [Regular Expression tokenization in the NLTK. Figure from Chapter 3 of @Bird2009],
  sourcecode[```
>>> text = 'That U.S.A. poster-print costs $12.40...'
>>> pattern = r'''(?x)    # set flag to allow verbose regexps
... (?:[A-Z]\.)+          # abbreviations, e.g. U.S.A.
... | \w+(?:-\w+)*        # words with optional internal hyphens
... | \$?\d+(?:\.\d+)?%?  # currency, percentages, e.g. $12.40, 82%
... | \.\.\.              # ellipsis
... | [][.,;"'?():_`-]    # these are separate tokens; includes ], [
... '''
>>> nltk.regexp_tokenize(text, pattern)
['That', 'U.S.A.', 'poster-print', 'costs', '$12.40', '...']

    ```],
    placement: auto
)<nltk>

Word tokenization is even more complex in languages like Chinese, Japanese and Thai, where there are no whitespaces that seperate words. In written Japanese, for example, kanji are Chinese-derived characters that represent a single morphone (a unit of meaning). Each kanji can have multiple meanings based on the surrounding context. Alongside kanji, Japanese uses two phonetic syllabaries: hiragana, for gramatical endings, particles, and native words words without kanji, and katakana, for foreign words and emphasis. Many words mix scripts, for example, 学校 (gakkō, “school”) uses two kanji, while 食べる (taberu, “to eat”) combines kanji with hiragana. Some words can also be written entirely in hiragana or katakana. Deciding what counts as a word in Japanese is a complex task, as the composition of characters to form words is highly depended on the surrounding context. For Chinese NLP tasks, the text is split up into characters, as they are at a reasonable semantic level. However, for Japanese and Thai, characters are too small of a semantic unit, so bottom-up subword tokenization alghorithms are required.