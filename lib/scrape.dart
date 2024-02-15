/* Copyright (C) 2024 Saladin Shaban
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'package:beautiful_soup_dart/beautiful_soup.dart';
import 'globals.dart';

class STMessage {
  final String permalink;
  final String author;
  final String message;

  STMessage(
      {required this.permalink, required this.author, required this.message});
}

class LoggedOutException implements Exception {
  final String message;

  LoggedOutException(this.message);

  @override
  String toString() => "LoggedOutException: $message";
}

List<STMessage> parseMessages(String html, [List<String>? errors]) {
  BeautifulSoup bs = BeautifulSoup(html);

  // Search for the specific <a> element
  Bs4Element? element = bs.find('a',
      class_: 'nav_sign_in btn_action green', attrs: {'href': '/?login'});

  if (element != null) {
    throw LoggedOutException("The user is logged out.");
  }

  List<STMessage> ret = [];
  List<Bs4Element> envelopes = bs.findAll('div', class_: 'comment_unread');

  for (Bs4Element envelope in envelopes) {
    try {
      Bs4Element? commentOuter = envelope.parent?.parent;
      if (commentOuter == null) {
        throw Exception("Outer comment element not found");
      }

      String? perma = commentOuter.findAll('a').lastOrNull?.attributes['href'];
      if (perma == null) {
        throw Exception("Permalink element not found");
      }

      String? author = commentOuter.find('a', class_: 'author_name')?.text;
      if (author == null) {
        throw Exception("Author element not found for permalink $perma");
      }

      String? comment = commentOuter
          .find('div', class_: 'comment_body_default markdown')
          ?.text
          .trim();
      if (comment == null) {
        throw Exception("Comment element not found for permalink $perma");
      }

      ret.add(STMessage(permalink: perma, author: author, message: comment));
    } catch (e) {
      logger.e("Error parsing message: $e");
      errors?.add("$e");
      continue;
    }
  }

  return ret;
}
