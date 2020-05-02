#install.packages(c('reticulate', 'cleanNLP', 'dplyr', 'stringr', 'tidyr', 'textstem'))

library(reticulate)
library(cleanNLP)
library(dplyr)
library(stringr)
library(tidyr)
library(textstem)

options(stringsAsFactors = FALSE)

#spaCy: change to the proper directory on your computer
use_python("C:/Users/Erin/Anaconda3") 
cnlp_init_spacy()

#get basic data
body <- read.csv("https://raw.githubusercontent.com/erdavis1/GenderedDescriptions/master/bodyparts.csv")
mastertext <- readLines('https://raw.githubusercontent.com/erdavis1/GenderedDescriptions/master/Emma.txt', encoding = "UTF-8")  %>% paste(collapse = " ") 
mastertext <- gsub("[â|€|œ|™]", "", mastertext)

#spacy can only process 900k-ish characters at once So we'll split the books into chunks and process 1 at a time.
lim <- 900000
final <- NULL
loops <- ceiling(nchar(mastertext)/lim)

#annotate and look in the text for pre-defined patterns
#these patterns I found by experimentation and trial and error. 
#not all instances of body parts will be associated with an owner here, depending on the construction of the sentence.
#It's not perfect but it gets a pretty decently sized set of data to analyze.

#I am targeting 3 types of sentences:
#1: simple possessives: HER <adjectives> HAIR
#2: had: SHE HAD <adjectives> HAIR
#3: possessives: THE GIRL'S <adjectives> HAIR
#4: verbs: HER HAIR WAS <adjectives>
for (j in 1:loops) {
  text <- substr(mastertext, (j-1)*lim+1, j*lim) 
  
  #annotate. this will take a bit
  obj <- cnlp_annotate(text)
  
  #get important bits
  tok <- obj$token
  bodytoken <- inner_join(body, tok, by = c("BodyPart" = "lemma")) %>%  subset(upos=="NOUN") %>% select(sid, tid, BodyPart)
  relwords <- tok %>% select(sid, tid, tid_source, relation, token, lemma)
  relwords <- inner_join(tok, relwords, by = c("sid", "tid_source" = "tid")) %>% select(sid, tid, tid_source, tid_source.y, relation.x, relation.y, token.x, token.y, lemma.x, lemma.y)
  
  #-------PART 1: SIMPLE POSSESIVES-------
  #simple possessives (her hair)
  simpleposs <-  inner_join(bodytoken, relwords, by = c("sid", "tid" = "tid_source")) 
  simpleposs <- simpleposs %>% subset(relation.x == 'poss') %>% select(sid, tid, BodyPart, token.x)
  names(simpleposs)[4] <- 'owner'
  
  #simple possessives with 1-2 adjectives (her long hair)
  simpleadj <-  inner_join(bodytoken, relwords, by = c("sid", "tid" = "tid_source")) 
  simpleadj <- simpleadj %>% subset(relation.x == 'amod')  %>% select(sid, tid, lemma.x)
  names(simpleadj)[3] <- 'adj'
  simpleposs <- left_join(simpleposs, simpleadj, by = c("sid", "tid"))
  
  #simple possessives with >2 adjectives (her long, beautiful, blonde hair)
  simplemanyadj <- inner_join(simpleadj, relwords, by = c("sid", "tid" = "tid_source.y")) %>% subset(relation.y == 'amod')
  simplemanyadj <- inner_join(simplemanyadj, tok, by = c("sid", "tid.y" = "tid")) 
  simplemanyadj <- simplemanyadj %>% subset(upos == 'ADJ') %>% select(sid, tid, token)

  temp <- inner_join(simpleposs, simplemanyadj, by = c("sid", "tid")) %>% select(sid, tid, BodyPart, owner, token) %>% unique()
  names(temp)[5] <- 'adj'
  simpleposs <- bind_rows(simpleposs, temp)

  
  #--------PART 2: HAD-------
  #owners of body parts w/ had or other verbs (she had hair)
  subject <- relwords %>% subset(relation.x %in% c('nsubjpass', 'nsubj')) %>% select(sid, tid, tid_source, token.x)
  object <-  inner_join(bodytoken, relwords, by = c("sid", "tid")) %>% subset(relation.x =='dobj')
  object <- object %>% select(sid, tid, tid_source, BodyPart)
  
  hadadj <- inner_join(object, subject, by = c("sid", "tid_source"))
  hadadj <- hadadj %>% select(sid, tid.x, BodyPart, token.x)
  names(hadadj)[c(2, 4)] <- c("tid", "owner")

  hadadj <- left_join(hadadj, simpleadj, by = c("sid", "tid"))
  
  #exclude anything already in simple poss
  hadadj <- left_join(hadadj, simpleposs, by = c("sid", "tid"))
  hadadj <- hadadj %>% subset(is.na(BodyPart.y))
  hadadj <- hadadj[, c(1, 2, 3, 4, 8)]
  names(hadadj)[c(3,4,5)] <- c("BodyPart", "owner", "adj")
  
  #--------PART 3: possessive 's (the girl's eyes)-------   
  poss  <- relwords %>% subset(relation.x == 'compound' & relation.y %in% c('nsubjpass', 'nsubj', 'compound')) %>% select(sid, tid, tid_source, tid_source.y, token.x)
  names(poss)[5] <- 'owner'
  
  #simple possessive
  poss1 <- inner_join(poss, relwords, by = c("sid", "tid_source" = "tid", "tid_source.y" = "tid_source"))
  poss1 <- poss1 %>% select(sid, tid, tid_source, tid_source.y, tid_source.y.y, relation.x, relation.y, token.y)
  names(poss1)[c(2, 3, 4, 5, 8)] <- c('tid_owner', 'tid', 'tid_source', 'tid_source.y', 'token')
  
  #get owners+body parts for possessive with an adjective (the girl's big eyes)
  poss2 <- inner_join(poss1, relwords, by = c("sid", "tid_source", "tid_source.y"))
  poss2 <- inner_join(poss2, bodytoken, by = c("sid", "tid.y" = 'tid'))
  poss2 <- poss2 %>% select(sid, tid_owner, tid.y, tid_source, tid_source.y, token.x)
  names(poss2)[c(3, 4, 6)] <- c('tid_source', 'tid', 'token')
  
  poss1 <- bind_rows(poss2, poss1)
  
  #remove any non-body-parts
  poss1 <- inner_join(poss1, bodytoken, by = c("sid", "tid_source" = "tid"))
  poss1 <- poss1[, c(1:5, 9)]
  
  #finally, go back and get adjectives
  possadj <- inner_join(poss1, relwords, by =c ("sid", "tid_source", "tid" = "tid_source.y"))
  possadj <- possadj %>% subset(relation.x == 'amod') %>% select(sid, tid_owner, token.x)
  names(possadj)[3] <- 'adj'
  
  #put it all together
  poss <- poss %>% select(sid, tid, owner)
  poss1 <- poss1 %>% select(sid, tid_owner, tid_source, BodyPart)
  poss <- inner_join(poss, poss1, by = c('sid', "tid" = "tid_owner"))
  poss <- left_join(poss, possadj, by = c('sid', 'tid' = 'tid_owner'))
  poss <- poss[, c(1, 4, 5, 3, 6)]
  names(poss)[2] <- 'tid'

    
  #--------PART 4: WAS/IS-------
  #adjectives separated by is/was or other verbs (her hair was long)
  owner <- inner_join(simpleposs, relwords, by = c("sid", "tid")) %>% select(sid, tid, tid_source, owner)
  owner <- inner_join(owner, relwords, by = c("sid", "tid", "tid_source")) %>% select(sid, tid, tid_source, tid_source.y, owner)
  
  adj <- inner_join(owner, relwords, by = c("sid", "tid_source", "tid_source.y")) 
  adj <- adj %>% subset(relation.x %in% c("advmod", "acomp"))
  adj <- adj %>% select(sid, tid.x, tid_source, tid.y, token.x)
  names(adj)[c(2:5)] <- c("tid_owner", "tid_source", "tid", "adj")
  
  #up to 4 other adjectives
  for (k in 1:4) {
    temp <-inner_join(adj, relwords, by = c("sid", "tid" = "tid_source", "tid_source" = "tid_source.y"))
    temp <- temp %>% subset(relation.y %in% c("advmod", "acomp", "conj") & !(relation.x %in%c("cc", "punct")))
    temp <- temp %>% select(sid, tid_owner, tid.y, tid, token.x)
    names(temp)[c(2:5)] <- c("tid_owner",  "tid", "tid_source", "adj")
    adj <- bind_rows(adj, temp) %>% unique()
    
  }
  
  adj <- adj %>% select("sid", "tid_owner", "adj")
  names(adj)[3] <- 'verb_adj'
  simpleposs <- left_join(simpleposs, adj, by = c("sid", "tid" = "tid_owner")) 
  simpleposs$adj[!is.na(simpleposs$verb_adj)] <- simpleposs$verb_adj[!is.na(simpleposs$verb_adj)] 
  simpleposs <- simpleposs[,1:5]
  
  #--------PART 5: Merge it all together-------
  final <- bind_rows(simpleposs, hadadj) %>% bind_rows(poss)  %>% bind_rows(final) %>% unique()
}


#----------ANALYSIS
#pre-identified list of gendered owners, constructed by hand
owners <- read.csv('https://raw.githubusercontent.com/erdavis1/GenderedDescriptions/master/owners.csv')

#filter parts down to just those with identified genders
final$owner <- tolower(final$owner)
final$owner <- gsub("[â|€|œ|™|.]", "", final$owner) #just in case any junk tagged along
parts_gen <- inner_join(final, owners, by = c("owner"))

#clean up and stem the adjectives
parts_gen$adj <- tolower(parts_gen$adj)
parts_gen$adj <- lemmatize_words(parts_gen$adj)

#summarize body part counts by book and in total
total_parts <- parts_gen %>% group_by(BodyPart, Gender) %>% summarize(total = n())
book_parts <- parts_gen %>% group_by(bookid, BodyPart, Gender) %>% summarize(total = n())

total_adj <- parts_gen %>% subset(!is.na(adj)) %>% group_by(BodyPart, adj, Gender) %>% summarize(total = n())
book_adj <- parts_gen %>% subset(!is.na(adj)) %>% group_by(bookid, BodyPart, adj, Gender) %>% summarize(total = n())

justadj <- parts_gen %>% subset(!is.na(adj)) %>% group_by(adj, Gender) %>% summarize(total = n())
just_bookadj <- parts_gen %>% subset(!is.na(adj)) %>% group_by(bookid, adj, Gender) %>% summarize(total = n())

#body part skew
bodyF <- subset(total_parts, Gender == "f") %>% ungroup()
bodyM <- subset(total_parts, Gender == "m")  %>% ungroup()

bodyF$pct <- bodyF$total/sum(bodyF$total)
bodyM$pct <- bodyM$total/sum(bodyM$total)

bodyskew <- data.frame(BodyPart = c(bodyF$BodyPart, bodyM$BodyPart) %>% unique())
bodyskew <- left_join(bodyskew, select(bodyM, BodyPart, total, pct), by = "BodyPart")
bodyskew <- left_join(bodyskew, select(bodyF, BodyPart, total, pct), by = "BodyPart")

names(bodyskew)[2:5] <- c("totalM", "pctM", "totalF", "pctF")
bodyskew[is.na(bodyskew)] <- 0

bodyskew$diff <- ifelse(bodyskew$pctM > bodyskew$pctF, bodyskew$pctM/bodyskew$pctF,  -bodyskew$pctF/bodyskew$pctM)

#adjective skew
adjF <- subset(justadj, Gender == "f") %>% ungroup()
adjM <- subset(justadj, Gender == "m")  %>% ungroup()

adjF$pct <- adjF$total/sum(adjF$total)
adjM$pct <- adjM$total/sum(adjM$total)

adjskew <- data.frame(adj= c(adjF$adj, adjM$adj) %>% unique())
adjskew <- left_join(adjskew, select(adjM, adj, total, pct), by = "adj")
adjskew <- left_join(adjskew, select(adjF, adj, total, pct), by = "adj")

names(adjskew)[2:5] <- c("totalM", "pctM", "totalF", "pctF")
adjskew[is.na(adjskew)] <- 0

adjskew$diff <- ifelse(adjskew$pctM > adjskew$pctF, adjskew$pctM/adjskew$pctF,  -adjskew$pctF/adjskew$pctM)


#adjective+bodypart skew
adjbodyF <- subset(total_adj, Gender == "f") %>% ungroup()
adjbodyM <- subset(total_adj, Gender == "m")  %>% ungroup()

adjbodyF$pct <- adjbodyF$total/sum(adjbodyF$total)
adjbodyM$pct <- adjbodyM$total/sum(adjbodyM$total)

adjbodyskew <- unique(select(total_adj, BodyPart, adj)) 
adjbodyskew <- left_join(adjbodyskew, select(adjbodyM, BodyPart, adj, total, pct), by = c("BodyPart", "adj"))
adjbodyskew <- left_join(adjbodyskew, select(adjbodyF, BodyPart, adj, total, pct), by = c("BodyPart", "adj"))

names(adjbodyskew)[3:6] <- c("totalM", "pctM", "totalF", "pctF")
adjbodyskew[is.na(adjbodyskew)] <- 0

adjbodyskew$diff <- ifelse(adjbodyskew$pctM > adjbodyskew$pctF, adjbodyskew$pctM/adjbodyskew$pctF,  -adjbodyskew$pctF/adjbodyskew$pctM)

adjbodyskew$total <- adjbodyskew$totalM  + adjbodyskew$totalF 

#save data for plotting
write.csv(bodyskew, "bodyskew.csv", row.names = FALSE)
write.csv(adjskew, "adjskew.csv", row.names = FALSE)
write.csv(adjbodyskew, "adjbodyskew.csv", row.names = FALSE)
write.csv(total_parts, "total_parts.csv")
write.csv(book_parts, "book_parts.csv")
write.csv(total_adj, "total_adj.csv")
write.csv(book_adj, "book_adj.csv")
write.csv(justadj, "justadj.csv")
write.csv(just_bookadj, "just_bookadj.csv")


