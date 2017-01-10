@smoke
Feature: Smoke


  @table_outline_fail
  Scenario Outline: Проверка наличия параметров
    Then Table step with param <parameter>
    When Not table step
    When Not table step
    Then Table step2 with param <parameter>
    Examples:
      |parameter|
      |iOS|
      |Android|


  @table_outline
  Scenario Outline: Проверка наличия параметров2
    Then Table step with param <parameter>
    When Not table step
    When Not table step
    Then Table step2 with param <parameter>
    Examples:
      |parameter|
      |iOS|
      |Android|