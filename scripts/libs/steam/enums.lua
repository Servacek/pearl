--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


return {
    --- @enum EPublishedFileQueryType
    EPublishedFileQueryType = {
        RankedByVote                                    = 0,
        RankedByPublicationDate                         = 1,
        AcceptedForGameRankedByAcceptanceDate           = 2,
        RankedByTrend                                   = 3,
        FavoritedByFriendsRankedByPublicationDate       = 4,
        CreatedByFriendsRankedByPublicationDate         = 5,
        RankedByNumTimesReported                        = 6,
        CreatedByFollowedUsersRankedByPublicationDate   = 7,
        NotYetRated                                     = 8,
        RankedByTotalUniqueSubscriptions                = 9,
        RankedByTotalVotesAsc                           = 10,
        RankedByVotesUp                                 = 11,
        RankedByTextSearch                              = 12,
        RankedByPlaytimeTrend                           = 13,
        RankedByTotalPlaytime                           = 14,
        RankedByAveragePlaytimeTrend                    = 15,
        RankedByLifetimeAveragePlaytime                 = 16,
        RankedByPlaytimeSessionsTrend                   = 17,
        RankedByLifetimePlaytimeSessions                = 18,
        RankedByInappropriateContentRating              = 19,
    }
}
