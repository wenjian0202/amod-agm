@routing @car @mode
Feature: Car - Mode flag
    Background:
        Given the profile "car"

    Scenario: Car - We tag ferries with a class
        Given the node map
            """
            a b
              c d
            """

        And the ways
            | nodes | highway | route |
            | ab    | primary |       |
            | bc    |         | ferry |
            | cd    | primary |       |

        When I route I should get
            | from | to | route       | turns                                              | classes                  |
            | a    | d  | ab,bc,cd,cd | depart,notification right,notification left,arrive | [()],[(ferry)],[()],[()] |
            | d    | a  | cd,bc,ab,ab | depart,notification right,notification left,arrive | [()],[(ferry)],[()],[()] |
            | c    | a  | bc,ab,ab    | depart,notification left,arrive                    | [(ferry)],[()],[()]      |
            | d    | b  | cd,bc,bc    | depart,notification right,arrive                   | [()],[(ferry)],[()]      |
            | a    | c  | ab,bc,bc    | depart,notification right,arrive                   | [()],[(ferry)],[()]      |
            | b    | d  | bc,cd,cd    | depart,notification left,arrive                    | [(ferry)],[()],[()]      |


    Scenario: Car - We tag motorways with a class
        Given the node map
            """
            a b
              c d
            """

        And the ways
            | nodes | highway |
            | ab    | primary |
            | bc    | motorway|
            | cd    | primary |

        When I route I should get
            | from | to | route    | turns         | classes                 |
            | a    | d  | ab,cd    | depart,arrive | [(),(motorway),()],[()] |
            | a    | c  | ab,bc    | depart,arrive | [(),(motorway)],[()]    |
            | b    | d  | bc,cd    | depart,arrive | [(motorway),()],[()]    |

    Scenario: Car - We tag motorway_link with a class
        Given the node map
            """
            a b
              c d
            """

        And the ways
            | nodes | highway       |
            | ab    | primary       |
            | bc    | motorway_link |
            | cd    | primary       |

        When I route I should get
            | from | to | route    | turns                       | classes                   | #                                |
            | a    | d  | ab,bc,cd | depart,on ramp right,arrive | [()],[(motorway),()],[()] | on-ramp at class change          |
            | a    | c  | ab,bc,bc | depart,on ramp right,arrive | [()],[(motorway)],[()]    |    "                "            |
            | b    | d  | bc,cd    | depart,arrive               | [(motorway),()],[()]      | no announcement                  |


    Scenario: Car - We tag restricted with a class
        Given the node map
            """
            a b
              c d
            """

        And the ways
            | nodes | highway | access   |
            | ab    | primary | private  |
            | bc    | motorway| private  |
            | cd    | primary |          |

        When I route I should get
            | from | to | route | turns        | classes                                      |
            | a    | d  | ab,cd | depart,arrive| [(restricted),(motorway,restricted),()],[()] |

    Scenario: Car - We toll restricted with a class
        Given the node map
            """
            a b
              c d
            """

        And the ways
            | nodes | highway | toll     |
            | ab    | primary | yes      |
            | bc    | motorway| yes      |
            | cd    | primary |          |

        When I route I should get
            | from | to | route    | turns         | classes                          |
            | a    | d  | ab,cd    | depart,arrive | [(toll),(motorway,toll),()],[()] |

    Scenario: Car - From roundabout on toll road
        Given the node map
            """
                     c
                  /     \
            a---b         d---f
                  \     /
                     e
                     |
                     g
            """

        And the ways
            | nodes | oneway | highway | junction   | toll     |
            | ab    | yes    | primary |            |          |
            | cb    | yes    | primary | roundabout |          |
            | dc    | yes    | primary | roundabout |          |
            | be    | yes    | primary | roundabout |          |
            | ed    | yes    | motorway| roundabout |          |
            | eg    | yes    | primary |            |          |
            | df    | yes    | motorway|            | yes      |

        When I route I should get
            | from | to | route    | turns                           | classes                                   |
            | a    | f  | ab,df,df | depart,roundabout-exit-2,arrive | [()],[(),(motorway),(toll,motorway)],[()] |

