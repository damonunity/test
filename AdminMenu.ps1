import logging
import time
import random
from datetime import datetime
import json
import os
from zlapi import *
from zlapi.models import *
import threading
import unicodedata
import re
import string

# Cấu hình logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Constants
GAME_DATA_FILE = "game_data.json"
GAME_TIMEOUT = 60  # Thời gian tối đa cho mỗi lượt
MAX_REPLY_COUNT = 3  # Số lượt trả lời tối đa
# Lock to protect shared game data
game_lock = threading.Lock()

class Bot(ZaloAPI):
    def __init__(self, api_key, secret_key, imei=None, session_cookies=None):
        super().__init__(api_key, secret_key, imei, session_cookies)
        self.game_data = self.load_game_data()

    def load_game_data(self):
        if os.path.exists(GAME_DATA_FILE):
            with open(GAME_DATA_FILE, "r") as f:
                try:
                    return json.load(f)
                except json.JSONDecodeError:
                    return {}
        return {}

    def save_game_data(self):
        with open(GAME_DATA_FILE, "w") as f:
            json.dump(self.game_data, f, indent=4)
    def normalize_vietnamese(self, text):
        """Chuẩn hóa tiếng Việt để loại bỏ dấu và các ký tự đặc biệt."""
        text = unicodedata.normalize('NFC', text).lower()
        text = re.sub(r'[^\w\s]', '', text)
        return text
    def is_valid_vietnamese_word(self, word):
        """Kiểm tra xem từ có phải là từ tiếng Việt hợp lệ 2 âm tiết hay không."""
        word = self.normalize_vietnamese(word)
        syllables = self.split_syllables(word)
        if len(syllables) != 2:
            return False
        return all(self.is_valid_syllable(syllable) for syllable in syllables)
    def is_valid_syllable(self, syllable):
      """Kiểm tra xem âm tiết có hợp lệ hay không (chứa nguyên âm)."""
      vowels = "aeiouyàảãáạăằẳẵắặâầẩẫấậèẻẽéẹêềểễếệìỉĩíịòỏõóọôồổỗốộơờởỡớợùủũúụưừửữứự"
      return any(v in syllable for v in vowels)
    def split_syllables(self, word):
        """Tách từ thành các âm tiết."""
        # Sử dụng regex để tách các âm tiết. Một âm tiết có thể bắt đầu bằng một hoặc nhiều phụ âm
        # và chứa một nguyên âm, và có thể kết thúc bằng một hoặc nhiều phụ âm
        return re.findall(r'[bcdfghjklmnpqrstvwxyz]*[aeiouyàảãáạăằẳẵắặâầẩẫấậèẻẽéẹêềểễếệìỉĩíịòỏõóọôồổỗốộơờởỡớợùủũúụưừửữứự]+[bcdfghjklmnpqrstvwxyz]*', word)
    def get_last_syllable(self, word):
        """Trả về âm tiết cuối cùng của từ."""
        word = self.normalize_vietnamese(word)
        syllables = self.split_syllables(word)
        if syllables:
           return syllables[-1]
        return ""
    def start_game(self, author_id, thread_id, thread_type):
        with game_lock:
            if thread_id not in self.game_data:
                self.game_data[thread_id] = {
                    "status": "playing",
                    "last_word": "",
                    "used_words": [],
                    "last_player": author_id,
                    "reply_count": 0,
                    "start_time": time.time(),
                    "thread_type": thread_type.name
                }
                self.save_game_data()
                self.sendMessage(Message(text="Trò chơi nối từ 2 âm tiết đã bắt đầu!"), thread_id, thread_type, ttl=10000)
                return True
            else:
                game_info = self.game_data[thread_id]
                if game_info["status"] == "playing":
                    self.sendMessage(Message(text=f"Trò chơi đang diễn ra, ai muốn chơi thì tham gia nhé. Lượt của {game_info['last_player']}"), thread_id, thread_type, ttl=10000)
                    return False
                else:
                    self.game_data[thread_id] = {
                        "status": "playing",
                        "last_word": "",
                        "used_words": [],
                        "last_player": author_id,
                        "reply_count": 0,
                        "start_time": time.time(),
                        "thread_type": thread_type.name
                    }
                    self.save_game_data()
                    self.sendMessage(Message(text="Trò chơi nối từ 2 âm tiết đã bắt đầu lại!"), thread_id, thread_type, ttl=10000)
                    return True
    def handle_game(self, message, message_object, author_id, thread_id, thread_type):
        with game_lock:
            if thread_id not in self.game_data or self.game_data[thread_id]["status"] == "ended":
                self.sendMessage(Message(text="Không có trò chơi nào đang diễn ra. Hãy bắt đầu bằng /startgame"), thread_id, thread_type, ttl=10000)
                return
            if self.game_data[thread_id]["last_player"] == author_id:
                 self.sendMessage(Message(text=f"Không phải lượt của bạn!"), thread_id, thread_type, ttl=10000)
                 return
            if self.game_data[thread_id]["reply_count"] >= MAX_REPLY_COUNT:
                 self.end_game(thread_id)
                 self.sendMessage(Message(text=f"Đã hết số lượt trả lời tối đa! Trò chơi kết thúc."), thread_id, thread_type, ttl=10000)
                 return
            # Xử lý timeout
            elapsed_time = time.time() - self.game_data[thread_id]["start_time"]
            if elapsed_time > GAME_TIMEOUT:
                self.end_game(thread_id)
                self.sendMessage(Message(text=f"Hết thời gian! Trò chơi kết thúc."), thread_id, thread_type, ttl=10000)
                return
            
            word = unicodedata.normalize('NFC', message).strip()
            if not self.is_valid_vietnamese_word(word):
                self.sendMessage(Message(text="Từ không hợp lệ! Vui lòng chọn từ tiếng Việt có 2 âm tiết."), thread_id, thread_type, ttl=10000)
                return
            
            if self.game_data[thread_id]["last_word"]:
              last_syllable = self.get_last_syllable(self.game_data[thread_id]["last_word"])
              if not self.normalize_vietnamese(word).startswith(last_syllable):
                    self.sendMessage(Message(text=f"Từ không bắt đầu bằng âm tiết cuối của từ trước ({last_syllable})!"), thread_id, thread_type, ttl=10000)
                    return
            
            if word in self.game_data[thread_id]["used_words"]:
                self.sendMessage(Message(text="Từ này đã được sử dụng rồi! Vui lòng chọn từ khác."), thread_id, thread_type, ttl=10000)
                return
            
            self.game_data[thread_id]["last_word"] = word
            self.game_data[thread_id]["used_words"].append(word)
            self.game_data[thread_id]["last_player"] = author_id
            self.game_data[thread_id]["reply_count"] += 1
            self.game_data[thread_id]["start_time"] = time.time()
            self.save_game_data()
            self.sendMessage(Message(text=f"Từ tiếp theo là: {word}"), thread_id, thread_type, ttl=10000)
    def end_game(self, thread_id):
        with game_lock:
            if thread_id in self.game_data:
                self.game_data[thread_id]["status"] = "ended"
                self.save_game_data()

    def onMessage(self, mid, author_id, message, message_object, thread_id, thread_type):
        super().onMessage(mid, author_id, message, message_object, thread_id, thread_type) # Call superclass method first

        str_message = str(message)
        if str_message.startswith('/startgame'):
            if self.start_game(author_id, thread_id, thread_type):
                self.replyMessage(Message(text="Hãy nhập từ đầu tiên"), message_object, thread_id, thread_type, ttl=10000)
        elif str_message.startswith('/endgame'):
            self.end_game(thread_id)
            self.sendMessage(Message(text="Trò chơi kết thúc."), thread_id, thread_type, ttl=10000)
        elif thread_id in self.game_data:
                self.handle_game(str_message, message_object, author_id, thread_id, thread_type)


client = Bot('api_key', 'secret_key', imei=imei, session_cookies=session_cookies)

client.listen(run_forever=True, delay=0, thread=True,type='requests')
