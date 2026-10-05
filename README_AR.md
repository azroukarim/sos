#####  install  
pip install cython

opkg install python3-cython





### send to path files plug
https://raw.githubusercontent.com/azroukarim/sos/refs/heads/main/setup_universal.py

### send to telnet 

cd /usr/lib/enigma2/python/Plugins/Extensions/XPortal
python setup_universal.py

###


killall -9 enigma2
















الآن:
ارفع 

setup_universal.py
 المحدّث إلى الريسيفر
شغّل على الريسيفر:
bash
cd /usr/lib/enigma2/python/Plugins/Extensions/XPortal
python setup_universal.py
الآن سيكتشف أن main_menu.py ليس له .so حقيقي ويجمّعه. وبعد ذلك شغّل Enigma2:

bash
killall -9 enigma2
