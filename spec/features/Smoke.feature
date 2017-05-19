@smoke
Feature: Smoke

  @table_outline
  Scenario Outline: Проверка наличия параметров
    Then Table step with param <parameter>
    When Not table step
    Then Table step2 with param <parameter>
    Examples:
      |parameter|
      |iOS|
      |Android|

  @test
  Scenario: Test
    Then Table step with param iOS
    When Not table step
    Then Table step2 with param Android