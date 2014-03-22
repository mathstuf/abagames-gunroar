Gunroar  readme.txt
for Windows98/2000/XP(要OpenGL)
ver. 0.15
(C) Kenta Cho

倍率ドン、さらに倍。
全方位ガンボートシューティング、Gunroar。


* 始め方

'gr0_15.zip'を展開し、'gr.exe'を実行してください。
ゲームを始めるにはショットキーを押してください。


* 遊び方

ボートを操舵して敵艦隊を沈めよう。

タイトルで上下キーまたはランスキーを押すことでゲームモードを
選択することができます。(NORMAL / TWIN STICK / DOUBLE PLAY / REPLAY)
ゲームモードによって操作方法が変わります。

- 操作 (NORMALモード)

2ボタンのパッド、スティックで操作する標準的なモードです。

o 移動
 方向キー / テンキー / [WASD] / [IJKL]  / スティック

o ショット / 方向固定
 [Z][L-Ctrl][R-Ctrl][.]                 / トリガ 1, 4, 5, 8, 9, 12

 押しっぱなしでガンが連射され、ボートの方向が固定されます。
 旋回しながら撃ちたい場合は、キーを軽く連射してください。

o ランス
 [X][L-Alt][R-Alt][L-Shift][R-Shift][/][Return] / トリガ 2, 3, 6, 7, 10, 11

 ランスは押しっぱなしでは連射されませんので、手連射してください。
 画面に前のランスが残っている間は、次のランスは発射できません。

- 操作 (TWIN STICKモード)

2つのスティックで操舵およびショットをするモードです。
アナログスティックで操作することを強く推奨します。

o 移動
 [WASD]   / スティック1 (Axis 1, 2)

o ショット
 [IJKL]   / スティック2 (Axis 3 / 5, 4)

 ショットの方向を指定します。
 強く倒すほどショットがその方向に集中し、弱く倒すと拡散します。
 （スティック2の方向に問題がある場合、'-rotatestick2'、'-reversestick2'
   オプションを試してください。例 '-rotatestick2 -90 -reversestick2'）
 （Xbox 360 有線コントローラを使っている場合は、'-enableaxis5'
   オプションを指定してください。）

- 操作 (DOUBLE PLAYモード)

2つのボートを同時に操作するモードです。

o ボート1移動
 [WASD]   / スティック1 (Axis 1, 2)

o ボート2移動
 [IJKL]   / スティック2 (Axis 3 / 5, 4)

- 操作 (MOUSEモード)

ボートをキーボードまたはパッドで操作し、照準をマウスで操作します。

o 移動
 方向キー / テンキー / [WASD] / [IJKL]  / スティック

o 照準の操作
 マウス

o ショット （狭）
 マウス左ボタン

o ショット （広）
 マウス右ボタン

- 操作 (共通)

o ポーズ
 [P]

o ゲーム終了 / タイトルに戻る
 [ESC]

- ランク倍率

ランク倍率（右上に表示）は、ゲームの難易度とともに上昇するボーナス倍率です。
より速く上方向に進むことで、より速くランク倍率を上昇させることができます。

- ボス出現タイマー

ボス出現タイマー（左上に表示）は、ボスが出現するまでの残り時間を表しています。


* オプション

以下のコマンドラインオプションが利用可能です。

 -brightness n  画面の明るさを設定します (n = 0 - 100, default = 100)
 -luminosity n  発光エフェクトの強さを設定します (n = 0 - 100, default = 0)
 -res x y       画面サイズを(x, y)に設定します (default = 640, 480)
 -nosound       音を再生しません
 -window        ウィンドウモードで起動します
 -exchange      ショットとランスのキーを入れ替えます
 -turnspeed n   旋回スピードを調節します (n = 0 - 500, default = 100) (NORMALモード)
 -firerear      ショット、ランスが船尾方向に発射されます (NORMALモード)
 -rotatestick2 n
   スティック2の入力方向をn度回転させます (default = 0) (TWIN STICK, DOUBLE PLAYモード)
 -reversestick2
   スティック2の入力方向左右反転させます (TWIN STICK, DOUBLE PLAYモード)
 -enableaxis5
   Axis 5をショットに使います。
   (Xbox 360 有線コントローラ用) (TWIN STICK, DOUBLE PLAYモード)

* コメント

ご意見、ご感想は cs8k-cyu@asahi-net.or.jp までお願いします。


* ウェブページ

Gunroar webpage:
http://www.asahi-net.or.jp/~cs8k-cyu/windows/gr.html


* 謝辞

GunroarはD言語(ver. 0.149)で記述されています。
 プログラミング言語D
 http://www.kmonos.net/alang/d/

メディアハンドリングにSimple DirectMedia Layerを利用しています。
 Simple DirectMedia Layer
 http://www.libsdl.org

BGMとSEの再生にSDL_mixerとOgg Vorbis CODECを利用しています。
 SDL_mixer 1.2
 http://www.libsdl.org/projects/SDL_mixer/
 Vorbis.com
 http://www.vorbis.com

D - portingのOpenGL, SDL, SDL_mixer用ヘッダファイルを利用しています。
 D - porting
 http://shinh.skr.jp/d/porting.html

乱数生成にMersenne Twisterを利用しています。
 Mersenne Twister: A random number generator (since 1997/10)
 http://www.math.sci.hiroshima-u.ac.jp/~m-mat/MT/emt.html


* ヒストリ

2006  3/18  ver. 0.15
            Added '-enableaxis5' option. (for xbox 360 wired controller)
2005  9/11  ver. 0.14
            Added mouse mode.
            Changed a drawing method of a game field.
            Fixed a problem with a score reel size in a double play mode.
            Increased the number of smoke particles.
2005  7/17  ver. 0.13
            Added double play mode.
2005  7/16  ver. 0.12
            Added '-rotatestick2' and '-reversestick2' options.
            Fixed a BGM problem in the replay mode.
2005  7/ 3  ver. 0.11
            Added twin stick mode.
            Added '-turnspeed' and '-firerear' options.
            Adjusted a position a scrolling starts.
            A score reel becomes small when a ship is in the bottom right.
            Added a field color changing feature.
2005  6/18  ver. 0.1
            First released version.


* ライセンス

修正BSDライセンスを適用します。

License
-------

Copyright 2005 Kenta Cho. All rights reserved.

Redistribution and use in source and binary forms,
with or without modification, are permitted provided that
the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice,
    this list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
    this list of conditions and the following disclaimer in the documentation
    and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
THE REGENTS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
