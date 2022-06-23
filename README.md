# tech-db-forum

Тестовое задание для реализации проекта "Форумы" на курсе по базам данных в Технопарке Mail.ru (https://park.vk.company).

Суть задания заключается в реализации API к базе данных проекта «Форумы» по документации к этому API.

Таким образом, на входе:

 * документация к API в файле ./swagger.yaml;

На выходе:

 * репозиторий, содержащий все необходимое для разворачивания сервиса в Docker-контейнере.

## Документация к API
Документация к API предоставлена в виде спецификации [OpenAPI](https://ru.wikipedia.org/wiki/OpenAPI_%28%D1%81%D0%BF%D0%B5%D1%86%D0%B8%D1%84%D0%B8%D0%BA%D0%B0%D1%86%D0%B8%D1%8F%29): swagger.yml

Документацию можно читать как собственно в файле swagger.yml, так и через Swagger UI: [editor.swagger.io](https://editor.swagger.io/)

## Требования к проекту
Проект должен включать в себя все необходимое для разворачивания сервиса в Docker-контейнере.

При этом:

 * файл для сборки Docker-контейнера должен называться Dockerfile и располагаться в корне репозитория;
 * реализуемое API должно быть доступно на 5000-ом порту по протоколу http;
 * допускается использовать любой язык программирования;
 * крайне не рекомендуется использовать ORM.

Контейнер будет собираться из запускаться командами вида:
```
docker build -t <username> https://github.com/mailcourses/technopark-dbms-forum-server.git
docker run -p 5000:5000 --name <username> -t <username>
```

## Функциональное тестирование
Корректность API будет проверяться при помощи автоматического функционального тестирования.

Методика тестирования:

 * собирается Docker-контейнер из репозитория;
 * запускается Docker-контейнер;
 * запускается скрипт на Go, который будет проводить тестирование;
 * останавливается Docker-контейнер.

Для локальной сборки Go-скрипта необходимо выполнить команду:
```
go get -u -v github.com/mailcourses/technopark-dbms-forum@master
go build github.com/mailcourses/technopark-dbms-forum
```
После этого в текущем каталоге будет создан исполняемый файл `technopark-dbms-forum`.

### Запуск функционального тестирования

Для запуска функционального тестирования нужно выполнить команду вида:
```
./technopark-dbms-forum func -u http://localhost:5000/api -r report.html
```

Поддерживаются следующие параметры:

Параметр                              | Описание
---                                   | ---
-h, --help                            | Вывод списка поддерживаемых параметров
-u, --url[=http://localhost:5000/api] | Указание базовой URL тестируемого приложения
-k, --keep                            | Продолжить тестирование после первого упавшего теста
-t, --tests[=.*]                      | Маска запускаемых тестов (регулярное выражение)
-r, --report[=report.html]            | Имя файла для детального отчета о функциональном тестировании

### Запуск нагрузочного тестирования

Для запуска нагрузочного тестирования нужно выполнить команду вида:
```
// заполнение:
./technopark-dbms-forum fill --url=http://localhost:5000/api --timeout=900

// тестирование:
./technopark-dbms-forum perf --url=http://localhost:5000/api --duration=600 --step=60
```
Параметры в примере означают:
- Лимит времени на заполнение базы - 15-ти минут;
- Нагрузка идёт 10 раз в течение 1-ой минуты. Учитывается лучший результат.
