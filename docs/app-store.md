# Публикация в App Store

Шпаргалка для App Store Connect. Тексты можно копировать как есть.

## Перед первой загрузкой

1. Включить GitHub Pages: Settings > Pages > Deploy from a branch, ветка `main`, папка `/docs`. Репозиторий для этого должен быть публичным (или перенести страницы на другой хостинг).
2. Проверить, что открываются:
   - https://eugenefedotov.github.io/exchange-rate/privacy.html
   - https://eugenefedotov.github.io/exchange-rate/support.html
3. В `Config/Local.xcconfig` вписать Team ID платного аккаунта.
4. В App Store Connect создать приложение с bundle id `com.eugenefedotov.ExchangeRate`. Виджет (`.RatesWidget`) отдельно заводить не надо.
5. В Xcode: Product > Archive, потом Distribute App > App Store Connect.
6. Написать в valuta.kg (письмо ниже) до отправки на ревью.

## Карточка приложения

- **Название:** Курсы Бишкека. "Курсы Валют" скорее всего занято, название в магазине должно быть уникальным. Под иконкой на телефоне останется "Курсы Валют".
- **Подзаголовок:** Обменки и банки, виджет
- **Основной язык:** русский
- **Категория:** Финансы, дополнительная - Утилиты
- **Цена:** бесплатно
- **Ключевые слова:** курс,валюта,сом,KGS,обменка,обменник,рубль,доллар,евро,тенге,Бакай,МБанк,донг,Бишкек,Киргизия
- **Privacy Policy URL:** https://eugenefedotov.github.io/exchange-rate/privacy.html
- **Support URL:** https://eugenefedotov.github.io/exchange-rate/support.html
- **Copyright:** 2026 и имя, как в аккаунте разработчика

**Описание:**

```
Курс рубля, доллара, евро и тенге к сому - в обменках Бишкека, в Бакай Банке и в МБанке.

- Обменки: средний курс по обменным пунктам Бишкека за последние 2 часа (valuta.kg).
- Банки: наличный и безналичный курс Бакай Банка и МБанка.
- Вьетнамский донг: сколько донгов за 1 рубль и за 1 сом по курсу ЦБ РФ.

Виджет для домашнего экрана и экрана блокировки. Источник переключается прямо на виджете, курс обновляется примерно раз в час.

Без регистрации, рекламы и сбора данных. Есть тёмная тема.

Курсы носят информационный характер. Перед обменом уточняйте курс в обменном пункте или банке.
```

**Скриншоты:** iPhone 6.9" (1320 x 2868), от 1 до 10 штук. Снимать в симуляторе iPhone 17 Pro Max: приложение, приложение в тёмной теме, домашний экран с виджетами.

## Анкеты

- **App Privacy:** Data Not Collected.
- **Возрастной рейтинг:** на все вопросы "Нет" / "None". Получится 4+.
- **Шифрование (Export Compliance):** в проекте уже стоит `ITSAppUsesNonExemptEncryption = NO`, вопрос задаваться не будет. Используется только HTTPS.
- **Content Rights:** "Да, содержит контент третьих лиц, и у меня есть права". Отвечать так после того, как valuta.kg ответит на письмо.
- **Страны:** без стран ЕС, тогда не нужен статус по DSA (trader / non-trader). Если ЕС нужен, указать non-trader.
- **Распространение:** можно выложить обычно, а можно после первого одобрения запросить Unlisted (форма по ссылке со страницы https://developer.apple.com/support/unlisted-app-distribution/). Тогда приложение будет доступно только по прямой ссылке.

## Заметки для ревью (App Review Information > Notes)

```
The app shows exchange rates to the Kyrgyz som in Bishkek (Kyrgyzstan): the average rate of Bishkek exchange offices, Bakai Bank and MBank, plus the Vietnamese dong rate from the Central Bank of Russia.

No sign-in is required. The app does not collect any user data, has no ads, analytics or tracking.

All data is publicly available on the source websites: valuta.kg, akchabar.kg, bakai.kg, mbank.kg and cbr.ru. Each source is named under the rates and opens in Safari from the "Sources" section, as valuta.kg requires attribution.

Widget: add the "Курсы Валют" widget to the Home Screen. Tapping the segments (or the dots on the small widget) switches the source. Cash or non-cash bank rates are chosen in Edit Widget > "Курс банков".
```

Логин для ревью не нужен, поле "Sign-in required" оставить выключенным.

## Письмо в valuta.kg

Адрес взять на странице https://valuta.kg/about.html (раздел "Информация для разработчиков") или в контактах сайта.

```
Здравствуйте!

Я сделал небольшое бесплатное приложение для iPhone с виджетом, которое показывает средний курс обменок Бишкека с valuta.kg ("Средний курс в Бишкеке"). Источник указан под курсами и открывается по нажатию, рекламы и платных функций нет.

Хочу опубликовать его в App Store. Подскажите, пожалуйста, можно ли использовать ваши данные в таком приложении? И если у вас есть данные в формате JSON или XML, о которых написано в разделе для разработчиков, я бы с радостью перешёл на них вместо чтения страницы. Запросы идут не чаще раза в 10 минут с устройства.

Спасибо!
```

Ответ (лучше письменное разрешение) сохранить: если ревьюер спросит про права на данные (guideline 5.2.2), его можно приложить в ответе в Resolution Center.

## Если ревью откажет

- **5.2.2 (данные третьих лиц):** приложить разрешение valuta.kg. Если спросят про банки, написать им же или убрать банк из приложения.
- **4.2 (минимальная функциональность):** упомянуть виджет с переключателем, наличный и безналичный курс, донг.
- **2.1 (не работает):** ревьюеры в США. Проверить, что valuta.kg и банки открываются не только из Бишкека (через VPN).
